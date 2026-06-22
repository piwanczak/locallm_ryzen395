#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <iostream>
#include <string>
#include <vector>

using GetIntFn = int(__cdecl *)();
using SetIntFn = int(__cdecl *)(int);

static std::wstring defaultDllPath() {
    return L"C:\\Program Files\\ASUS\\ARMOURY CRATE ProArt Service\\ThrottlePlugin\\NativeGamingCenterHelper.dll";
}

static std::wstring parentDir(const std::wstring &path) {
    size_t pos = path.find_last_of(L"\\/");
    if (pos == std::wstring::npos) {
        return L".";
    }
    return path.substr(0, pos);
}

static bool hasArg(int argc, wchar_t **argv, const wchar_t *name) {
    for (int i = 1; i < argc; ++i) {
        if (std::wstring(argv[i]) == name) {
            return true;
        }
    }
    return false;
}

static bool readIntArg(int argc, wchar_t **argv, const wchar_t *name, int *value) {
    for (int i = 1; i + 1 < argc; ++i) {
        if (std::wstring(argv[i]) == name) {
            *value = _wtoi(argv[i + 1]);
            return true;
        }
    }
    return false;
}

static std::vector<std::string> readStringArgs(int argc, wchar_t **argv, const wchar_t *name) {
    std::vector<std::string> values;
    for (int i = 1; i + 1 < argc; ++i) {
        if (std::wstring(argv[i]) == name) {
            std::wstring wide = argv[i + 1];
            values.emplace_back(wide.begin(), wide.end());
        }
    }
    return values;
}

static void printGet(HMODULE dll, const char *name) {
    auto fn = reinterpret_cast<GetIntFn>(GetProcAddress(dll, name));
    if (!fn) {
        std::cout << name << "=<missing>\n";
        return;
    }

    std::cout << name << "=" << fn() << "\n";
}

static void callSet(HMODULE dll, const char *name, int value) {
    auto fn = reinterpret_cast<SetIntFn>(GetProcAddress(dll, name));
    if (!fn) {
        std::cout << name << "(missing)\n";
        return;
    }

    int rc = fn(value);
    std::cout << name << "(" << value << ")=" << rc << "\n";
}

static void callNoArg(HMODULE dll, const char *name) {
    auto fn = reinterpret_cast<GetIntFn>(GetProcAddress(dll, name));
    if (!fn) {
        std::cout << name << "(missing)\n";
        return;
    }

    int rc = fn();
    std::cout << name << "()=" << rc << "\n";
}

int wmain(int argc, wchar_t **argv) {
    std::wstring dllPath = defaultDllPath();
    for (int i = 1; i + 1 < argc; ++i) {
        if (std::wstring(argv[i]) == L"--dll") {
            dllPath = argv[i + 1];
        }
    }

    SetDllDirectoryW(parentDir(dllPath).c_str());
    HMODULE dll = LoadLibraryExW(dllPath.c_str(), nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (!dll) {
        std::wcerr << L"LoadLibraryExW failed rc=" << GetLastError() << L" path=" << dllPath << L"\n";
        return 2;
    }
    std::cout << "LoadLibraryExW=ok\n";

    if (hasArg(argc, argv, L"--load-only")) {
        FreeLibrary(dll);
        return 0;
    }

    int value = 0;
    const bool unsafeSetters = hasArg(argc, argv, L"--unsafe-enable-setters");
    if (!unsafeSetters && (
        readIntArg(argc, argv, L"--set-throttle", &value) ||
        readIntArg(argc, argv, L"--set-power-mode", &value) ||
        readIntArg(argc, argv, L"--set-power-policy", &value) ||
        readIntArg(argc, argv, L"--set-windows-power-mode", &value) ||
        readIntArg(argc, argv, L"--set-performance-mode", &value) ||
        readIntArg(argc, argv, L"--set-gpu-type", &value) ||
        readIntArg(argc, argv, L"--set-thermal-policy", &value) ||
        hasArg(argc, argv, L"--use-performance-mode") ||
        hasArg(argc, argv, L"--delete-use-performance-mode"))) {
        std::cout << "Setter arguments ignored. Re-run with --unsafe-enable-setters after verifying exact signatures.\n";
    }

    if (unsafeSetters) {
        if (readIntArg(argc, argv, L"--set-throttle", &value)) {
            callSet(dll, "SetGamingCenterThrottleMode", value);
        }
        if (readIntArg(argc, argv, L"--set-power-mode", &value)) {
            callSet(dll, "SetGamingCenterPowerMode", value);
        }
        if (readIntArg(argc, argv, L"--set-power-policy", &value)) {
            callSet(dll, "SetPowerModePolicy", value);
        }
        if (readIntArg(argc, argv, L"--set-windows-power-mode", &value)) {
            callSet(dll, "SetWindowsPowerMode", value);
        }
        if (readIntArg(argc, argv, L"--set-performance-mode", &value)) {
            callSet(dll, "SetPerformanceMode", value);
        }
        if (readIntArg(argc, argv, L"--set-gpu-type", &value)) {
            callSet(dll, "SetGpuType", value);
        }
        if (readIntArg(argc, argv, L"--set-thermal-policy", &value)) {
            callSet(dll, "SetThermalPolicy", value);
        }
        if (hasArg(argc, argv, L"--use-performance-mode")) {
            callNoArg(dll, "UsePerformanceMode");
        }
        if (hasArg(argc, argv, L"--delete-use-performance-mode")) {
            callNoArg(dll, "DeleteUsePerformanceMode");
        }
    }

    std::vector<std::string> requestedGetters = readStringArgs(argc, argv, L"--get");
    std::cout << "GETTERS:\n";
    const char *defaultGetters[] = {
        "GetGamingCenterThrottleMode",
        "GetGamingCenterPowerMode",
        "GetPowerModePolicy",
        "GetWindowsPowerMode",
        "GetGpuType",
        "GetThermalPolicy",
        "GetPowerModeEnabled",
        "HasBeenSetPowerModeSync",
        "GetGamingCenterManualModeAppliedStatus",
        "GetAdapterWattageInformation",
        "GetPDStatus",
        "GetPDNewGenerationEnabled",
        "GetATKInterfaceVersion",
        "GetCPUVendor",
    };

    if (!requestedGetters.empty()) {
        for (const auto &name : requestedGetters) {
            printGet(dll, name.c_str());
        }
    } else {
        for (const char *name : defaultGetters) {
            printGet(dll, name);
        }
    }

    FreeLibrary(dll);
    return 0;
}
