#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <powrprof.h>

#include <algorithm>
#include <cstdlib>
#include <iostream>

#ifndef PowerRequestExecutionRequired
#define PowerRequestExecutionRequired static_cast<POWER_REQUEST_TYPE>(3)
#endif

int main(int argc, char **argv) {
    int seconds = 1800;
    if (argc > 1) {
        seconds = std::max(1, std::atoi(argv[1]));
    }

    REASON_CONTEXT reason = {};
    reason.Version = POWER_REQUEST_CONTEXT_VERSION;
    reason.Flags = POWER_REQUEST_CONTEXT_SIMPLE_STRING;
    reason.Reason.SimpleReasonString = const_cast<LPWSTR>(L"LM Studio local inference throughput optimization");

    HANDLE request = PowerCreateRequest(&reason);
    if (!request || request == INVALID_HANDLE_VALUE) {
        std::cerr << "PowerCreateRequest failed: " << GetLastError() << "\n";
        return 2;
    }

    const POWER_REQUEST_TYPE requests[] = {
        PowerRequestSystemRequired,
        PowerRequestDisplayRequired,
        PowerRequestExecutionRequired,
    };

    bool anyFailed = false;
    for (POWER_REQUEST_TYPE requestType : requests) {
        if (!PowerSetRequest(request, requestType)) {
            std::cerr << "PowerSetRequest(" << static_cast<int>(requestType) << ") failed: "
                      << GetLastError() << "\n";
            anyFailed = true;
        }
    }

    EXECUTION_STATE previous = SetThreadExecutionState(
        ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED | ES_AWAYMODE_REQUIRED);
    if (previous == 0) {
        std::cerr << "SetThreadExecutionState failed: " << GetLastError() << "\n";
        anyFailed = true;
    }

    std::cout << "seconds=" << seconds << "\n";
    std::cout << "power_request_handle=" << request << "\n";
    std::cout << "execution_previous_state=0x" << std::hex << previous << std::dec << "\n";
    std::cout << "partial_failure=" << (anyFailed ? 1 : 0) << "\n";

    Sleep(static_cast<DWORD>(seconds) * 1000U);

    for (POWER_REQUEST_TYPE requestType : requests) {
        PowerClearRequest(request, requestType);
    }
    CloseHandle(request);
    SetThreadExecutionState(ES_CONTINUOUS);
    return anyFailed ? 1 : 0;
}
