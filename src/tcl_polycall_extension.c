#include "tcl_polycall.h"

#include <stdio.h>
#include <tcl.h>

#define TCL_POLYCALL_VERSION "1.0.0"

static int get_config_path(
    Tcl_Interp *interp,
    Tcl_Size objc,
    Tcl_Obj *const objv[],
    const char **config_path
) {
    if (objc > 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "?configPath?");
        return TCL_ERROR;
    }

    *config_path = objc == 2 ? Tcl_GetString(objv[1]) : "tcl-polycallrc";
    return TCL_OK;
}

static int run_config_command(
    void *client_data,
    Tcl_Interp *interp,
    Tcl_Size objc,
    Tcl_Obj *const objv[]
) {
    const char *config_path;
    int32_t status;

    (void)client_data;
    if (get_config_path(interp, objc, objv, &config_path) != TCL_OK) {
        return TCL_ERROR;
    }

    status = tcl_polycall_run_config(config_path);
    Tcl_SetObjResult(interp, Tcl_NewWideIntObj((Tcl_WideInt)status));
    return TCL_OK;
}

static int run_config_or_error_command(
    void *client_data,
    Tcl_Interp *interp,
    Tcl_Size objc,
    Tcl_Obj *const objv[]
) {
    const char *config_path;
    char status_text[32];
    int32_t status;

    (void)client_data;
    if (get_config_path(interp, objc, objv, &config_path) != TCL_OK) {
        return TCL_ERROR;
    }

    status = tcl_polycall_run_config(config_path);
    Tcl_SetObjResult(interp, Tcl_NewWideIntObj((Tcl_WideInt)status));
    if (status == 0) {
        return TCL_OK;
    }

    (void)snprintf(status_text, sizeof(status_text), "%ld", (long)status);
    Tcl_SetErrorCode(interp, "POLYCALL", "STATUS", status_text, NULL);
    Tcl_SetObjResult(
        interp,
        Tcl_ObjPrintf("libpolycall run_config failed with status %ld", (long)status)
    );
    return TCL_ERROR;
}

DLLEXPORT int Tclpolycall_Init(Tcl_Interp *interp) {
    if (Tcl_InitStubs(interp, "9.0", 0) == NULL) {
        return TCL_ERROR;
    }

    if (Tcl_FindNamespace(interp, "::polycall", NULL, TCL_GLOBAL_ONLY) == NULL &&
        Tcl_CreateNamespace(interp, "::polycall", NULL, NULL) == NULL) {
        return TCL_ERROR;
    }

    if (Tcl_CreateObjCommand2(
            interp,
            "::polycall::run_config",
            run_config_command,
            NULL,
            NULL
        ) == NULL ||
        Tcl_CreateObjCommand2(
            interp,
            "::polycall::run_config_or_error",
            run_config_or_error_command,
            NULL,
            NULL
        ) == NULL) {
        return TCL_ERROR;
    }

    return Tcl_PkgProvide(interp, "tcl-polycall", TCL_POLYCALL_VERSION);
}
