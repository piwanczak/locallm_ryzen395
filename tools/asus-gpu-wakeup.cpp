#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <chrono>
#include <cstdlib>
#include <iostream>
#include <string>
#include <thread>

using CreateGPUControlClassInstanceFn = int(__cdecl *)(bool, int, void **, int);
using DeleteGPUControlClassInstanceFn = void(__cdecl *)(void *);
using WakupGPUByReadFreqFn = int(__cdecl *)(void *);

static std::wstring defaultDllPath() {
    return L"C:\\Program Files\\ASUS\\ARMOURY CRATE ProArt Service\\ThrottlePlugin\\GPUControlLibrary.dll";
}

static std::wstring parentDir(const std::wstring &path) {
    size_t pos = path.find_last_of(L"\\/");
    if (pos == std::wstring::npos) {
        return L".";
    }
    return path.substr(0, pos);
}

int wmain(int argc, wchar_t **argv) {
    int iterations = 8;
    int sleepMs = 250;
    bool flag = true;
    int apiVersion = 2;
    int gpuType = 0;
    std::wstring dllPath = defaultDllPath();

    for (int i = 1; i < argc; ++i) {
        std::wstring arg = argv[i];
        if (arg == L"--iterations" && i + 1 < argc) {
            iterations = std::max(1, _wtoi(argv[++i]));
        } else if (arg == L"--sleep-ms" && i + 1 < argc) {
            sleepMs = std::max(0, _wtoi(argv[++i]));
        } else if (arg == L"--flag" && i + 1 < argc) {
            flag = _wtoi(argv[++i]) != 0;
        } else if (arg == L"--api-version" && i + 1 < argc) {
            apiVersion = _wtoi(argv[++i]);
        } else if (arg == L"--gpu-type" && i + 1 < argc) {
            gpuType = _wtoi(argv[++i]);
        } else if (arg == L"--dll" && i + 1 < argc) {
            dllPath = argv[++i];
        }
    }

    std::wstring dllDir = parentDir(dllPath);
    SetDllDirectoryW(dllDir.c_str());

    HMODULE dll = LoadLibraryExW(dllPath.c_str(), nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (!dll) {
        std::wcerr << L"LoadLibraryW failed: " << GetLastError() << L" path=" << dllPath << L"\n";
        return 2;
    }

    auto createFn = reinterpret_cast<CreateGPUControlClassInstanceFn>(
        GetProcAddress(dll, "CreateGPUControlClassInstance"));
    auto deleteFn = reinterpret_cast<DeleteGPUControlClassInstanceFn>(
        GetProcAddress(dll, "DeleteGPUControlClassInstance"));
    auto wakeFn = reinterpret_cast<WakupGPUByReadFreqFn>(
        GetProcAddress(dll, "WakupGPUByReadFreq"));

    if (!createFn || !deleteFn || !wakeFn) {
        std::cerr << "Required exports missing\n";
        FreeLibrary(dll);
        return 3;
    }

    void *instance = nullptr;
    int createRc = createFn(flag, apiVersion, &instance, gpuType);
    std::cout << "create_rc=" << createRc << "\n";
    std::cout << "instance=" << instance << "\n";
    std::cout << "flag=" << (flag ? 1 : 0) << "\n";
    std::cout << "api_version=" << apiVersion << "\n";
    std::cout << "gpu_type=" << gpuType << "\n";

    if (!instance) {
        FreeLibrary(dll);
        return 4;
    }

    for (int i = 0; i < iterations; ++i) {
        int wakeRc = wakeFn(instance);
        std::cout << "wake_rc[" << i << "]=" << wakeRc << "\n";
        if (sleepMs > 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(sleepMs));
        }
    }

    deleteFn(instance);
    FreeLibrary(dll);
    return 0;
}
