#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <algorithm>
#include <cstdlib>
#include <iostream>

int main(int argc, char **argv) {
    int seconds = 120;
    if (argc > 1) {
        seconds = std::max(1, std::atoi(argv[1]));
    }

    EXECUTION_STATE state = ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED | ES_AWAYMODE_REQUIRED;
    EXECUTION_STATE previous = SetThreadExecutionState(state);
    if (previous == 0) {
        std::cerr << "SetThreadExecutionState failed: " << GetLastError() << "\n";
        return 2;
    }

    std::cout << "seconds=" << seconds << "\n";
    std::cout << "previous_state=0x" << std::hex << previous << std::dec << "\n";
    Sleep(static_cast<DWORD>(seconds) * 1000U);

    SetThreadExecutionState(ES_CONTINUOUS);
    return 0;
}
