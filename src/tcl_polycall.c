/*
 * tcl-polycall -- Tcl 9 loadable extension over the Polycall binding ABI v1
 * (polycall.h, libpolycall >= 1.1.0).
 *
 *   load tclpolycall[info sharedlibextension] Tclpolycall   (or package require tcl-polycall)
 *
 * Commands (namespace ::polycall):
 *   abi_version | version | strerror CODE | last_error
 *   run_config ?PATH? ?STRICT?           -> status (0 = POLYCALL_OK); STRICT defaults to 1
 *   run_config_or_error ?PATH? ?STRICT?  -> 0, or a Tcl error
 *   describe PATH                        -> JSON
 *   call ENDPOINT SERVICE OPERATION ?INPUT_JSON? ?TIMEOUT_MS? -> output JSON
 *   peer open NODE_ID ?BIND? ?TOKEN?     -> handle ("" BIND = send-only, "" TOKEN = none)
 *   peer close|endpoint|node_id|cancel|health|list|list_json HANDLE
 *   peer register HANDLE PEER_ID ENDPOINT | peer unregister HANDLE PEER_ID
 *   peer ping HANDLE PEER ?TIMEOUT_MS?
 *   peer send HANDLE PEER BYTES ?MESSAGE_ID? ?TIMEOUT_MS?
 *   peer recv HANDLE TIMEOUT_MS|forever ?CAPACITY?  -> dict sender .. message_id .. payload BYTES
 *
 * Failures raise a Tcl error whose -errorcode is
 *   {POLYCALL <POLYCALL_E_NAME> <status> <polycall_last_error detail> ?<extra>?}
 * where <extra> is the remote error object of `call`, or the needed size of
 * a `peer recv` whose buffer was too small (the message stays queued).
 *
 * The library is linked through pkg-config (polycall.pc); Tclpolycall_Init
 * refuses a library whose polycall_ffi_abi_version() is not 1.
 */

#include <polycall.h>
#include <tcl.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TCL_POLYCALL_VERSION "1.1.0"
#define DETAIL_MAX 1024

/* ---- errors ------------------------------------------------------------- */

static void status_name(int status, char *buf, size_t cap)
{
    const char *text = polycall_strerror(status);
    const char *colon = strchr(text, ':');
    size_t n = colon ? (size_t)(colon - text) : strlen(text);
    if (n >= cap) n = cap - 1;
    memcpy(buf, text, n);
    buf[n] = '\0';
}

/* Raise the Tcl error for `status`; `extra` (may be NULL) is appended to
 * -errorcode. Reads polycall_last_error() first, before anything else can
 * overwrite this thread's detail. */
static int fail(Tcl_Interp *interp, int status, const char *what, Tcl_Obj *extra)
{
    char detail[DETAIL_MAX], name[64], code[16];
    Tcl_Obj *ec;

    polycall_last_error(detail, sizeof detail);
    status_name(status, name, sizeof name);
    snprintf(code, sizeof code, "%d", status);
    ec = Tcl_NewListObj(0, NULL);
    Tcl_ListObjAppendElement(NULL, ec, Tcl_NewStringObj("POLYCALL", -1));
    Tcl_ListObjAppendElement(NULL, ec, Tcl_NewStringObj(name, -1));
    Tcl_ListObjAppendElement(NULL, ec, Tcl_NewStringObj(code, -1));
    Tcl_ListObjAppendElement(NULL, ec, Tcl_NewStringObj(detail, -1));
    if (extra) Tcl_ListObjAppendElement(NULL, ec, extra);
    Tcl_SetObjErrorCode(interp, ec);
    if (detail[0]) {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s: %s (status=%d): %s", what,
                                               polycall_strerror(status), status, detail));
    } else {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("%s: %s (status=%d)", what,
                                               polycall_strerror(status), status));
    }
    return TCL_ERROR;
}

static int check(Tcl_Interp *interp, int status, const char *what)
{
    return status == POLYCALL_OK ? TCL_OK : fail(interp, status, what, NULL);
}

/* ---- argument helpers ----------------------------------------------------- */

static int get_handle(Tcl_Interp *interp, Tcl_Obj *obj, polycall_peer_t *out)
{
    Tcl_WideInt v;
    if (Tcl_GetWideIntFromObj(interp, obj, &v) != TCL_OK) return TCL_ERROR;
    if (v < INT32_MIN || v > INT32_MAX) {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("peer handle out of int32 range: %s", Tcl_GetString(obj)));
        Tcl_SetErrorCode(interp, "POLYCALL", "POLYCALL_E_INVALID_ARGUMENT", "-1", "handle out of range", NULL);
        return TCL_ERROR;
    }
    *out = (polycall_peer_t)v;
    return TCL_OK;
}

/* uint32 milliseconds; "forever" = UINT32_MAX */
static int get_timeout(Tcl_Interp *interp, Tcl_Obj *obj, uint32_t *out)
{
    Tcl_WideInt v;
    if (strcmp(Tcl_GetString(obj), "forever") == 0) {
        *out = UINT32_MAX;
        return TCL_OK;
    }
    if (Tcl_GetWideIntFromObj(interp, obj, &v) != TCL_OK) return TCL_ERROR;
    if (v < 0 || v > (Tcl_WideInt)UINT32_MAX) {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf("timeout must be 0..4294967295 or forever: %s", Tcl_GetString(obj)));
        Tcl_SetErrorCode(interp, "POLYCALL", "POLYCALL_E_INVALID_ARGUMENT", "-1", "bad timeout", NULL);
        return TCL_ERROR;
    }
    *out = (uint32_t)v;
    return TCL_OK;
}

/* NULL for "" (optional C strings) */
static const char *opt_string(Tcl_Obj *obj)
{
    const char *s = Tcl_GetString(obj);
    return *s ? s : NULL;
}

/* Run a (handle, buf, cap, &len) function, growing the buffer as needed. */
typedef int (*sized_fn)(polycall_peer_t, char *, size_t, size_t *);
static int sized_text(Tcl_Interp *interp, sized_fn fn, polycall_peer_t h, const char *what)
{
    size_t cap = 4096, len = 0;
    int attempt, st;
    for (attempt = 0; attempt < 4; ++attempt) {
        char *buf = (char *)Tcl_Alloc(cap);
        st = fn(h, buf, cap, &len);
        if (st == POLYCALL_OK) {
            Tcl_SetObjResult(interp, Tcl_NewStringObj(buf, (Tcl_Size)len));
            Tcl_Free(buf);
            return TCL_OK;
        }
        Tcl_Free(buf);
        if (st != POLYCALL_E_TOO_LARGE) return fail(interp, st, what, NULL);
        cap = len + 1;
    }
    return fail(interp, POLYCALL_E_TOO_LARGE, what, NULL);
}

/* ---- library / configuration / call --------------------------------------- */

static int AbiVersionCmd(void *cd, Tcl_Interp *interp, Tcl_Size objc, Tcl_Obj *const objv[])
{
    (void)cd;
    if (objc != 1) { Tcl_WrongNumArgs(interp, 1, objv, NULL); return TCL_ERROR; }
    Tcl_SetObjResult(interp, Tcl_NewIntObj(polycall_ffi_abi_version()));
    return TCL_OK;
}

static int VersionCmd(void *cd, Tcl_Interp *interp, Tcl_Size objc, Tcl_Obj *const objv[])
{
    char buf[64];
    int n;
    (void)cd;
    if (objc != 1) { Tcl_WrongNumArgs(interp, 1, objv, NULL); return TCL_ERROR; }
    n = polycall_ffi_version(buf, (int)sizeof buf);
    if (n < 0) return fail(interp, n, "polycall version", NULL);
    Tcl_SetObjResult(interp, Tcl_NewStringObj(buf, -1));
    return TCL_OK;
}

static int StrerrorCmd(void *cd, Tcl_Interp *interp, Tcl_Size objc, Tcl_Obj *const objv[])
{
    int code;
    (void)cd;
    if (objc != 2) { Tcl_WrongNumArgs(interp, 1, objv, "status"); return TCL_ERROR; }
    if (Tcl_GetIntFromObj(interp, objv[1], &code) != TCL_OK) return TCL_ERROR;
    Tcl_SetObjResult(interp, Tcl_NewStringObj(polycall_strerror(code), -1));
    return TCL_OK;
}

static int LastErrorCmd(void *cd, Tcl_Interp *interp, Tcl_Size objc, Tcl_Obj *const objv[])
{
    char buf[DETAIL_MAX];
    (void)cd;
    if (objc != 1) { Tcl_WrongNumArgs(interp, 1, objv, NULL); return TCL_ERROR; }
    polycall_last_error(buf, sizeof buf);
    Tcl_SetObjResult(interp, Tcl_NewStringObj(buf, -1));
    return TCL_OK;
}

static int config_args(Tcl_Interp *interp, Tcl_Size objc, Tcl_Obj *const objv[],
                       const char **path, int *strict)
{
    if (objc > 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "?configPath? ?strict?");
        return TCL_ERROR;
    }
    *path = objc >= 2 ? Tcl_GetString(objv[1]) : "tcl-polycallrc";
    *strict = 1;
    if (objc == 3 && Tcl_GetBooleanFromObj(interp, objv[2], strict) != TCL_OK) return TCL_ERROR;
    return TCL_OK;
}

/* Documented entry point: returns the core status of
 * polycall_ffi_run_config(path, 1) unchanged (strict 0 -> run=0). */
static int RunConfigCmd(void *cd, Tcl_Interp *interp, Tcl_Size objc, Tcl_Obj *const objv[])
{
    const char *path;
    int strict;
    (void)cd;
    if (config_args(interp, objc, objv, &path, &strict) != TCL_OK) return TCL_ERROR;
    Tcl_SetObjResult(interp, Tcl_NewIntObj(polycall_ffi_run_config(path, strict ? 1 : 0)));
    return TCL_OK;
}

static int RunConfigOrErrorCmd(void *cd, Tcl_Interp *interp, Tcl_Size objc, Tcl_Obj *const objv[])
{
    const char *path;
    int strict, st;
    (void)cd;
    if (config_args(interp, objc, objv, &path, &strict) != TCL_OK) return TCL_ERROR;
    st = polycall_ffi_run_config(path, strict ? 1 : 0);
    if (st != POLYCALL_OK) {
        Tcl_Obj *what = Tcl_ObjPrintf("run_config %s", path);
        int rc;
        Tcl_IncrRefCount(what);
        rc = fail(interp, st, Tcl_GetString(what), NULL);
        Tcl_DecrRefCount(what);
        return rc;
    }
    Tcl_SetObjResult(interp, Tcl_NewIntObj(0));
    return TCL_OK;
}

static int DescribeCmd(void *cd, Tcl_Interp *interp, Tcl_Size objc, Tcl_Obj *const objv[])
{
    const char *path;
    int cap = 65536, n, attempt;
    (void)cd;
    if (objc != 2) { Tcl_WrongNumArgs(interp, 1, objv, "configPath"); return TCL_ERROR; }
    path = Tcl_GetString(objv[1]);
    for (attempt = 0; attempt < 4; ++attempt) {
        char *buf = (char *)Tcl_Alloc((size_t)cap);
        n = polycall_ffi_describe(path, buf, cap);
        if (n >= 0 && n < cap) {
            Tcl_SetObjResult(interp, Tcl_NewStringObj(buf, n));
            Tcl_Free(buf);
            return TCL_OK;
        }
        Tcl_Free(buf);
        if (n < 0) return fail(interp, n, "describe", NULL);
        cap = n + 1;
    }
    return fail(interp, POLYCALL_E_TOO_LARGE, "describe", NULL);
}

static int CallCmd(void *cd, Tcl_Interp *interp, Tcl_Size objc, Tcl_Obj *const objv[])
{
    uint32_t timeout = 5000;
    size_t len = 0;
    const char *input = NULL;
    char *out;
    int st;
    (void)cd;
    if (objc < 4 || objc > 6) {
        Tcl_WrongNumArgs(interp, 1, objv, "endpoint service operation ?inputJson? ?timeoutMs?");
        return TCL_ERROR;
    }
    if (objc >= 5) input = opt_string(objv[4]);
    if (objc == 6 && get_timeout(interp, objv[5], &timeout) != TCL_OK) return TCL_ERROR;
    out = (char *)Tcl_Alloc(POLYCALL_CALL_MAX_OUTPUT);
    st = polycall_call(Tcl_GetString(objv[1]), Tcl_GetString(objv[2]), Tcl_GetString(objv[3]),
                       input, timeout, out, POLYCALL_CALL_MAX_OUTPUT, &len);
    if (st != POLYCALL_OK) {
        Tcl_Obj *extra = Tcl_NewStringObj(st == POLYCALL_E_TOO_LARGE ? "" : out, -1);
        Tcl_Obj *what = Tcl_ObjPrintf("call %s.%s at %s", Tcl_GetString(objv[2]),
                                      Tcl_GetString(objv[3]), Tcl_GetString(objv[1]));
        int rc;
        Tcl_Free(out);
        Tcl_IncrRefCount(what);
        rc = fail(interp, st, Tcl_GetString(what), extra);
        Tcl_DecrRefCount(what);
        return rc;
    }
    Tcl_SetObjResult(interp, Tcl_NewStringObj(out, (Tcl_Size)len));
    Tcl_Free(out);
    return TCL_OK;
}

/* ---- peer ----------------------------------------------------------------- */

/* {"id":"host:port",...} -> Tcl dict. Ids are [A-Za-z0-9._-] and endpoints
 * host:port, so the registry JSON never contains escapes. */
static Tcl_Obj *registry_dict(const char *json)
{
    Tcl_Obj *d = Tcl_NewDictObj();
    const char *p = json;
    for (;;) {
        const char *k0, *k1, *v0, *v1;
        k0 = strchr(p, '"');
        if (!k0) break;
        k1 = strchr(k0 + 1, '"');
        if (!k1) break;
        v0 = strchr(k1 + 1, '"');
        if (!v0) break;
        v1 = strchr(v0 + 1, '"');
        if (!v1) break;
        Tcl_DictObjPut(NULL, d, Tcl_NewStringObj(k0 + 1, (Tcl_Size)(k1 - k0 - 1)),
                       Tcl_NewStringObj(v0 + 1, (Tcl_Size)(v1 - v0 - 1)));
        p = v1 + 1;
    }
    return d;
}

static int PeerCmd(void *cd, Tcl_Interp *interp, Tcl_Size objc, Tcl_Obj *const objv[])
{
    static const char *const subs[] = {
        "open", "close", "endpoint", "node_id", "register", "unregister", "list", "list_json",
        "ping", "send", "recv", "cancel", "health", NULL
    };
    enum { P_OPEN, P_CLOSE, P_ENDPOINT, P_NODE_ID, P_REGISTER, P_UNREGISTER, P_LIST, P_LIST_JSON,
           P_PING, P_SEND, P_RECV, P_CANCEL, P_HEALTH };
    int idx;
    polycall_peer_t h = 0;
    (void)cd;

    if (objc < 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "subcommand ?arg ...?");
        return TCL_ERROR;
    }
    if (Tcl_GetIndexFromObj(interp, objv[1], subs, "subcommand", 0, &idx) != TCL_OK) return TCL_ERROR;

    if (idx == P_OPEN) {
        polycall_peer_t out = 0;
        int st;
        if (objc < 3 || objc > 5) {
            Tcl_WrongNumArgs(interp, 2, objv, "nodeId ?bindEndpoint? ?authToken?");
            return TCL_ERROR;
        }
        st = polycall_peer_open(Tcl_GetString(objv[2]),
                                objc >= 4 ? opt_string(objv[3]) : "127.0.0.1:0",
                                objc >= 5 ? opt_string(objv[4]) : NULL, &out);
        if (st != POLYCALL_OK) return fail(interp, st, "peer open", NULL);
        Tcl_SetObjResult(interp, Tcl_NewIntObj((int)out));
        return TCL_OK;
    }

    if (get_handle(interp, objv[2], &h) != TCL_OK) return TCL_ERROR;

    switch (idx) {
    case P_CLOSE:
    case P_CANCEL:
        if (objc != 3) { Tcl_WrongNumArgs(interp, 2, objv, "handle"); return TCL_ERROR; }
        return check(interp, idx == P_CLOSE ? polycall_peer_close(h) : polycall_peer_cancel(h),
                     idx == P_CLOSE ? "peer close" : "peer cancel");
    case P_ENDPOINT:
    case P_NODE_ID: {
        char buf[POLYCALL_ENDPOINT_MAX];
        int st;
        if (objc != 3) { Tcl_WrongNumArgs(interp, 2, objv, "handle"); return TCL_ERROR; }
        st = idx == P_ENDPOINT ? polycall_peer_endpoint(h, buf, sizeof buf)
                               : polycall_peer_node_id(h, buf, sizeof buf);
        if (st != POLYCALL_OK) return fail(interp, st, idx == P_ENDPOINT ? "peer endpoint" : "peer node_id", NULL);
        Tcl_SetObjResult(interp, Tcl_NewStringObj(buf, -1));
        return TCL_OK;
    }
    case P_REGISTER:
        if (objc != 5) { Tcl_WrongNumArgs(interp, 2, objv, "handle peerId endpoint"); return TCL_ERROR; }
        return check(interp, polycall_peer_register(h, Tcl_GetString(objv[3]), Tcl_GetString(objv[4])),
                     "peer register");
    case P_UNREGISTER:
        if (objc != 4) { Tcl_WrongNumArgs(interp, 2, objv, "handle peerId"); return TCL_ERROR; }
        return check(interp, polycall_peer_unregister(h, Tcl_GetString(objv[3])), "peer unregister");
    case P_LIST:
    case P_LIST_JSON:
        if (objc != 3) { Tcl_WrongNumArgs(interp, 2, objv, "handle"); return TCL_ERROR; }
        if (sized_text(interp, polycall_peer_list, h, "peer list") != TCL_OK) return TCL_ERROR;
        if (idx == P_LIST) Tcl_SetObjResult(interp, registry_dict(Tcl_GetString(Tcl_GetObjResult(interp))));
        return TCL_OK;
    case P_HEALTH:
        if (objc != 3) { Tcl_WrongNumArgs(interp, 2, objv, "handle"); return TCL_ERROR; }
        return sized_text(interp, polycall_peer_health, h, "peer health");
    case P_PING: {
        uint32_t timeout = 2000;
        if (objc < 4 || objc > 5) { Tcl_WrongNumArgs(interp, 2, objv, "handle peer ?timeoutMs?"); return TCL_ERROR; }
        if (objc == 5 && get_timeout(interp, objv[4], &timeout) != TCL_OK) return TCL_ERROR;
        return check(interp, polycall_peer_ping(h, Tcl_GetString(objv[3]), timeout), "peer ping");
    }
    case P_SEND: {
        uint32_t timeout = 5000;
        const char *mid = NULL;
        unsigned char *bytes;
        Tcl_Size n = 0;
        if (objc < 5 || objc > 7) {
            Tcl_WrongNumArgs(interp, 2, objv, "handle peer bytes ?messageId? ?timeoutMs?");
            return TCL_ERROR;
        }
        /* binary-safe: the payload is a byte array (encoding convertto / binary format) */
        bytes = Tcl_GetBytesFromObj(interp, objv[4], &n);
        if (!bytes) return TCL_ERROR;
        if (objc >= 6) mid = opt_string(objv[5]);
        if (objc == 7 && get_timeout(interp, objv[6], &timeout) != TCL_OK) return TCL_ERROR;
        return check(interp, polycall_peer_send(h, Tcl_GetString(objv[3]), bytes, (size_t)n, mid, timeout),
                     "peer send");
    }
    case P_RECV: {
        uint32_t timeout;
        Tcl_WideInt capw = POLYCALL_PEER_MAX_PAYLOAD;
        char sender[POLYCALL_PEER_ID_MAX], mid[POLYCALL_MESSAGE_ID_MAX];
        unsigned char *buf;
        size_t len = 0, cap;
        int st;
        Tcl_Obj *d;
        if (objc < 4 || objc > 5) {
            Tcl_WrongNumArgs(interp, 2, objv, "handle timeoutMs|forever ?capacity?");
            return TCL_ERROR;
        }
        if (get_timeout(interp, objv[3], &timeout) != TCL_OK) return TCL_ERROR;
        if (objc == 5 && Tcl_GetWideIntFromObj(interp, objv[4], &capw) != TCL_OK) return TCL_ERROR;
        if (capw < 0 || capw > (Tcl_WideInt)(64u << 20)) {
            Tcl_SetObjResult(interp, Tcl_NewStringObj("capacity must be 0..67108864", -1));
            return TCL_ERROR;
        }
        cap = (size_t)capw;
        buf = (unsigned char *)Tcl_Alloc(cap ? cap : 1);
        st = polycall_peer_recv(h, timeout, sender, sizeof sender, mid, sizeof mid, buf, cap, &len);
        if (st == POLYCALL_E_TOO_LARGE) {
            Tcl_Free(buf);
            return fail(interp, st, "peer recv", Tcl_NewWideIntObj((Tcl_WideInt)len));
        }
        if (st != POLYCALL_OK) {
            Tcl_Free(buf);
            return fail(interp, st, "peer recv", NULL);
        }
        d = Tcl_NewDictObj();
        Tcl_DictObjPut(NULL, d, Tcl_NewStringObj("sender", -1), Tcl_NewStringObj(sender, -1));
        Tcl_DictObjPut(NULL, d, Tcl_NewStringObj("message_id", -1), Tcl_NewStringObj(mid, -1));
        Tcl_DictObjPut(NULL, d, Tcl_NewStringObj("payload", -1), Tcl_NewByteArrayObj(buf, (Tcl_Size)len));
        Tcl_Free(buf);
        Tcl_SetObjResult(interp, d);
        return TCL_OK;
    }
    default:
        break;
    }
    Tcl_SetObjResult(interp, Tcl_NewStringObj("unreachable", -1));
    return TCL_ERROR;
}

/* ---- init ------------------------------------------------------------------- */

DLLEXPORT int Tclpolycall_Init(Tcl_Interp *interp)
{
    static const struct { const char *name; Tcl_ObjCmdProc2 *proc; } cmds[] = {
        { "::polycall::abi_version", AbiVersionCmd },
        { "::polycall::version", VersionCmd },
        { "::polycall::strerror", StrerrorCmd },
        { "::polycall::last_error", LastErrorCmd },
        { "::polycall::run_config", RunConfigCmd },
        { "::polycall::run_config_or_error", RunConfigOrErrorCmd },
        { "::polycall::describe", DescribeCmd },
        { "::polycall::call", CallCmd },
        { "::polycall::peer", PeerCmd },
    };
    size_t i;
    int abi;

    if (Tcl_InitStubs(interp, "9.0", 0) == NULL) return TCL_ERROR;

    abi = polycall_ffi_abi_version();
    if (abi != POLYCALL_FFI_ABI_VERSION) {
        Tcl_SetObjResult(interp, Tcl_ObjPrintf(
            "tcl-polycall: the loaded libpolycall reports binding ABI %d; this extension requires ABI %d",
            abi, POLYCALL_FFI_ABI_VERSION));
        Tcl_SetErrorCode(interp, "POLYCALL", "POLYCALL_E_UNSUPPORTED", "-15", "ABI mismatch", NULL);
        return TCL_ERROR;
    }

    if (Tcl_FindNamespace(interp, "::polycall", NULL, TCL_GLOBAL_ONLY) == NULL &&
        Tcl_CreateNamespace(interp, "::polycall", NULL, NULL) == NULL) {
        return TCL_ERROR;
    }
    for (i = 0; i < sizeof cmds / sizeof cmds[0]; ++i) {
        if (Tcl_CreateObjCommand2(interp, cmds[i].name, cmds[i].proc, NULL, NULL) == NULL) return TCL_ERROR;
    }
    Tcl_SetVar2Ex(interp, "::polycall::WAIT_FOREVER", NULL, Tcl_NewStringObj("forever", -1), TCL_GLOBAL_ONLY);
    return Tcl_PkgProvide(interp, "tcl-polycall", TCL_POLYCALL_VERSION);
}
