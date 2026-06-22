#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>

#define ADL_MAX_PATH 256

typedef void* (__stdcall *ADL_MAIN_MALLOC_CALLBACK)(int);
typedef void* ADL_CONTEXT_HANDLE;

struct AdapterInfo {
    int iSize;
    int iAdapterIndex;
    char strUDID[ADL_MAX_PATH];
    int iBusNumber;
    int iDeviceNumber;
    int iFunctionNumber;
    int iVendorID;
    char strAdapterName[ADL_MAX_PATH];
    char strDisplayName[ADL_MAX_PATH];
    int iPresent;
    int iExist;
    char strDriverPath[ADL_MAX_PATH];
    char strDriverPathExt[ADL_MAX_PATH];
    char strPNPString[ADL_MAX_PATH];
    int iOSDisplayIndex;
};

struct ADLMemoryInfo2 {
    long long iMemorySize;
    char strMemoryType[ADL_MAX_PATH];
    long long iMemoryBandwidth;
    long long iHyperMemorySize;
    long long iInvisibleMemorySize;
    long long iVisibleMemorySize;
};

struct ADLODNPerformanceStatus {
    int iCoreClock;
    int iMemoryClock;
    int iDCEFClock;
    int iGFXClock;
    int iUVDClock;
    int iVCEClock;
    int iGPUActivityPercent;
    int iCurrentCorePerformanceLevel;
    int iCurrentMemoryPerformanceLevel;
    int iCurrentDCEFPerformanceLevel;
    int iCurrentGFXPerformanceLevel;
    int iUVDPerformanceLevel;
    int iVCEPerformanceLevel;
    int iCurrentBusSpeed;
    int iCurrentBusLanes;
    int iMaximumBusLanes;
    int iVDDC;
    int iVDDCI;
};

constexpr int ADL_PMLOG_MAX_SENSORS = 256;

struct ADLSingleSensorData {
    int supported;
    int value;
};

struct ADLPMLogDataOutput {
    int size;
    ADLSingleSensorData sensors[ADL_PMLOG_MAX_SENSORS];
};

constexpr int OD8_COUNT = 77;

struct ADLOD8SingleInitSetting {
    int featureID;
    int minValue;
    int maxValue;
    int defaultValue;
};

struct ADLOD8InitSetting {
    int count;
    int overdrive8Capabilities;
    ADLOD8SingleInitSetting od8SettingTable[OD8_COUNT];
};

struct ADLOD8CurrentSetting {
    int count;
    int Od8SettingTable[OD8_COUNT];
};

typedef int (__stdcall *ADL2_Main_Control_Create_t)(ADL_MAIN_MALLOC_CALLBACK, int, ADL_CONTEXT_HANDLE*);
typedef int (__stdcall *ADL2_Main_Control_Destroy_t)(ADL_CONTEXT_HANDLE);
typedef int (__stdcall *ADL2_Adapter_NumberOfAdapters_Get_t)(ADL_CONTEXT_HANDLE, int*);
typedef int (__stdcall *ADL2_Adapter_AdapterInfo_Get_t)(ADL_CONTEXT_HANDLE, AdapterInfo*, int);
typedef int (__stdcall *ADL2_Adapter_ObservedClockInfo_Get_t)(ADL_CONTEXT_HANDLE, int, int*, int*);
typedef int (__stdcall *ADL2_Adapter_MemoryInfo2_Get_t)(ADL_CONTEXT_HANDLE, int, ADLMemoryInfo2*);
typedef int (__stdcall *ADL2_Adapter_DedicatedVRAMUsage_Get_t)(ADL_CONTEXT_HANDLE, int, int*);
typedef int (__stdcall *ADL2_Adapter_SharedVRAMUsage_Get_t)(ADL_CONTEXT_HANDLE, int, int*);
typedef int (__stdcall *ADL2_Adapter_Speed_Caps_t)(ADL_CONTEXT_HANDLE, int, int*, int*);
typedef int (__stdcall *ADL2_Adapter_Speed_Get_t)(ADL_CONTEXT_HANDLE, int, int*, int*);
typedef int (__stdcall *ADL2_OverdriveN_PerformanceStatus_Get_t)(ADL_CONTEXT_HANDLE, int, ADLODNPerformanceStatus*);
typedef int (__stdcall *ADL2_OverdriveN_ThrottleNotification_Get_t)(ADL_CONTEXT_HANDLE, int, int*, int*);
typedef int (__stdcall *ADL2_New_QueryPMLogData_Get_t)(ADL_CONTEXT_HANDLE, int, ADLPMLogDataOutput*);
typedef int (__stdcall *ADL2_Overdrive8_Init_Setting_Get_t)(ADL_CONTEXT_HANDLE, int, ADLOD8InitSetting*);
typedef int (__stdcall *ADL2_Overdrive8_Current_Setting_Get_t)(ADL_CONTEXT_HANDLE, int, ADLOD8CurrentSetting*);

struct SensorName {
    int id;
    const char* name;
};

static const SensorName interestingSensors[] = {
    {1, "CLK_GFXCLK"},
    {2, "CLK_MEMCLK"},
    {3, "CLK_SOCCLK"},
    {8, "TEMPERATURE_EDGE"},
    {9, "TEMPERATURE_MEM"},
    {17, "SOC_POWER"},
    {23, "ASIC_POWER"},
    {27, "TEMPERATURE_HOTSPOT"},
    {28, "TEMPERATURE_GFX"},
    {29, "TEMPERATURE_SOC"},
    {30, "GFX_POWER"},
    {32, "TEMPERATURE_CPU"},
    {33, "CPU_POWER"},
    {34, "CLK_CPUCLK"},
    {38, "SMART_POWERSHIFT_CPU"},
    {39, "SMART_POWERSHIFT_DGPU"},
    {44, "CLK_FCLK"},
    {46, "SSPAIRED_ASICPOWER"},
    {47, "SSTOTAL_POWERLIMIT"},
    {48, "SSAPU_POWERLIMIT"},
    {52, "THROTTLE_PERCENTAGE_TEMP_GFX"},
    {53, "THROTTLE_PERCENTAGE_TEMP_MEM"},
    {54, "THROTTLE_PERCENTAGE_TEMP_VR"},
    {55, "THROTTLE_PERCENTAGE_POWER"},
    {71, "CLK_NPUCLK"},
    {73, "BOARD_POWER"},
    {74, "TEMPERATURE_INTAKE"},
};

static const SensorName interestingOd8Settings[] = {
    {0, "OD8_GFXCLK_FMAX"},
    {1, "OD8_GFXCLK_FMIN"},
    {8, "OD8_UCLK_FMAX"},
    {9, "OD8_POWER_PERCENTAGE"},
    {13, "OD8_OPERATING_TEMP_MAX"},
    {33, "OD8_GFXCLK_CURVE_VFT_FMIN"},
    {34, "OD8_UCLK_FMIN"},
    {36, "OD8_OPTIMZED_POWER_MODE"},
    {47, "OD8_TDC_PERCENTAGE"},
    {48, "OD8_FULL_CONTROL_MODE_SETTING"},
    {49, "OD8_FULL_CONTROL_MODE_GFXCLK"},
    {50, "OD8_FULL_CONTROL_MODE_UCLK"},
    {51, "OD8_IDLE_POWER_SAVING_FEATURE_CONTROL"},
    {52, "OD8_RUNTIME_POWER_SAVING_FEATURE_CONTROL"},
    {53, "OD8_FULL_CONTROL_MODE_FEATURE_CONTROL"},
};

static void* __stdcall adl_malloc(int size) {
    return std::malloc(static_cast<size_t>(size));
}

template <typename T>
static T proc(HMODULE dll, const char* name) {
    return reinterpret_cast<T>(GetProcAddress(dll, name));
}

static std::string safe(const char* text) {
    if (!text) {
        return "";
    }
    return std::string(text, strnlen(text, ADL_MAX_PATH));
}

int main() {
    HMODULE dll = LoadLibraryW(L"C:\\Windows\\System32\\atiadlxx.dll");
    if (!dll) {
        std::cerr << "load_atiadlxx_error=" << GetLastError() << "\n";
        return 2;
    }

    auto create = proc<ADL2_Main_Control_Create_t>(dll, "ADL2_Main_Control_Create");
    auto destroy = proc<ADL2_Main_Control_Destroy_t>(dll, "ADL2_Main_Control_Destroy");
    auto getCount = proc<ADL2_Adapter_NumberOfAdapters_Get_t>(dll, "ADL2_Adapter_NumberOfAdapters_Get");
    auto getInfo = proc<ADL2_Adapter_AdapterInfo_Get_t>(dll, "ADL2_Adapter_AdapterInfo_Get");
    auto getObservedClock = proc<ADL2_Adapter_ObservedClockInfo_Get_t>(dll, "ADL2_Adapter_ObservedClockInfo_Get");
    auto getMemoryInfo2 = proc<ADL2_Adapter_MemoryInfo2_Get_t>(dll, "ADL2_Adapter_MemoryInfo2_Get");
    auto getDedicatedUsage = proc<ADL2_Adapter_DedicatedVRAMUsage_Get_t>(dll, "ADL2_Adapter_DedicatedVRAMUsage_Get");
    auto getSharedUsage = proc<ADL2_Adapter_SharedVRAMUsage_Get_t>(dll, "ADL2_Adapter_SharedVRAMUsage_Get");
    auto getSpeedCaps = proc<ADL2_Adapter_Speed_Caps_t>(dll, "ADL2_Adapter_Speed_Caps");
    auto getSpeed = proc<ADL2_Adapter_Speed_Get_t>(dll, "ADL2_Adapter_Speed_Get");
    auto getPerf = proc<ADL2_OverdriveN_PerformanceStatus_Get_t>(dll, "ADL2_OverdriveN_PerformanceStatus_Get");
    auto getThrottle = proc<ADL2_OverdriveN_ThrottleNotification_Get_t>(dll, "ADL2_OverdriveN_ThrottleNotification_Get");
    auto getPMLog = proc<ADL2_New_QueryPMLogData_Get_t>(dll, "ADL2_New_QueryPMLogData_Get");
    auto getOd8Init = proc<ADL2_Overdrive8_Init_Setting_Get_t>(dll, "ADL2_Overdrive8_Init_Setting_Get");
    auto getOd8Current = proc<ADL2_Overdrive8_Current_Setting_Get_t>(dll, "ADL2_Overdrive8_Current_Setting_Get");

    if (!create || !destroy || !getCount || !getInfo) {
        std::cerr << "missing_required_adl_exports\n";
        return 3;
    }

    ADL_CONTEXT_HANDLE context = nullptr;
    int rc = create(adl_malloc, 1, &context);
    std::cout << "ADL2_Main_Control_Create=" << rc << "\n";
    if (rc != 0 || !context) {
        return 4;
    }

    int numAdapters = 0;
    rc = getCount(context, &numAdapters);
    std::cout << "ADL2_Adapter_NumberOfAdapters_Get=" << rc << "\n";
    std::cout << "adapter_count=" << numAdapters << "\n";

    if (rc == 0 && numAdapters > 0 && numAdapters < 64) {
        size_t bytes = sizeof(AdapterInfo) * static_cast<size_t>(numAdapters);
        AdapterInfo* adapters = static_cast<AdapterInfo*>(std::calloc(static_cast<size_t>(numAdapters), sizeof(AdapterInfo)));
        for (int i = 0; i < numAdapters; ++i) {
            adapters[i].iSize = static_cast<int>(sizeof(AdapterInfo));
        }

        int infoRc = getInfo(context, adapters, static_cast<int>(bytes));
        std::cout << "ADL2_Adapter_AdapterInfo_Get=" << infoRc << "\n";

        for (int i = 0; i < numAdapters; ++i) {
            const AdapterInfo& a = adapters[i];
            std::cout << "\n[adapter " << i << "]\n";
            std::cout << "index=" << a.iAdapterIndex << "\n";
            std::cout << "name=" << safe(a.strAdapterName) << "\n";
            std::cout << "display=" << safe(a.strDisplayName) << "\n";
            std::cout << "vendor_id=0x" << std::hex << a.iVendorID << std::dec << "\n";
            std::cout << "present=" << a.iPresent << "\n";
            std::cout << "exist=" << a.iExist << "\n";
            std::cout << "bus_device_function=" << a.iBusNumber << ":" << a.iDeviceNumber << ":" << a.iFunctionNumber << "\n";
            std::cout << "pnp=" << safe(a.strPNPString) << "\n";

            if (getObservedClock) {
                int core = -1;
                int memory = -1;
                int clockRc = getObservedClock(context, a.iAdapterIndex, &core, &memory);
                std::cout << "observed_clock_rc=" << clockRc << "\n";
                std::cout << "observed_core_clock=" << core << "\n";
                std::cout << "observed_memory_clock=" << memory << "\n";
            }

            if (getMemoryInfo2) {
                ADLMemoryInfo2 mem{};
                int memRc = getMemoryInfo2(context, a.iAdapterIndex, &mem);
                std::cout << "memory_info2_rc=" << memRc << "\n";
                if (memRc == 0) {
                    std::cout << "memory_size_bytes=" << mem.iMemorySize << "\n";
                    std::cout << "memory_type=" << safe(mem.strMemoryType) << "\n";
                    std::cout << "memory_bandwidth_MBps=" << mem.iMemoryBandwidth << "\n";
                    std::cout << "hyper_memory_size_bytes=" << mem.iHyperMemorySize << "\n";
                    std::cout << "visible_memory_size_bytes=" << mem.iVisibleMemorySize << "\n";
                    std::cout << "invisible_memory_size_bytes=" << mem.iInvisibleMemorySize << "\n";
                }
            }

            if (getDedicatedUsage) {
                int dedicatedMb = -1;
                int dedicatedRc = getDedicatedUsage(context, a.iAdapterIndex, &dedicatedMb);
                std::cout << "dedicated_vram_usage_rc=" << dedicatedRc << "\n";
                std::cout << "dedicated_vram_usage_MB=" << dedicatedMb << "\n";
            }

            if (getSharedUsage) {
                int sharedMb = -1;
                int sharedRc = getSharedUsage(context, a.iAdapterIndex, &sharedMb);
                std::cout << "shared_vram_usage_rc=" << sharedRc << "\n";
                std::cout << "shared_vram_usage_MB=" << sharedMb << "\n";
            }

            if (getSpeedCaps) {
                int caps = -1;
                int valid = -1;
                int speedCapsRc = getSpeedCaps(context, a.iAdapterIndex, &caps, &valid);
                std::cout << "speed_caps_rc=" << speedCapsRc << "\n";
                std::cout << "speed_caps=" << caps << "\n";
                std::cout << "speed_valid=" << valid << "\n";
            }

            if (getSpeed) {
                int current = -1;
                int defaultValue = -1;
                int speedRc = getSpeed(context, a.iAdapterIndex, &current, &defaultValue);
                std::cout << "speed_get_rc=" << speedRc << "\n";
                std::cout << "speed_current=" << current << "\n";
                std::cout << "speed_default=" << defaultValue << "\n";
            }

            if (getPerf) {
                ADLODNPerformanceStatus perf{};
                int perfRc = getPerf(context, a.iAdapterIndex, &perf);
                std::cout << "odn_performance_status_rc=" << perfRc << "\n";
                if (perfRc == 0) {
                    std::cout << "odn_core_clock=" << perf.iCoreClock << "\n";
                    std::cout << "odn_memory_clock=" << perf.iMemoryClock << "\n";
                    std::cout << "odn_dcef_clock=" << perf.iDCEFClock << "\n";
                    std::cout << "odn_gfx_clock=" << perf.iGFXClock << "\n";
                    std::cout << "odn_gpu_activity_percent=" << perf.iGPUActivityPercent << "\n";
                    std::cout << "odn_core_perf_level=" << perf.iCurrentCorePerformanceLevel << "\n";
                    std::cout << "odn_memory_perf_level=" << perf.iCurrentMemoryPerformanceLevel << "\n";
                    std::cout << "odn_current_bus_speed=" << perf.iCurrentBusSpeed << "\n";
                    std::cout << "odn_current_bus_lanes=" << perf.iCurrentBusLanes << "\n";
                    std::cout << "odn_max_bus_lanes=" << perf.iMaximumBusLanes << "\n";
                    std::cout << "odn_vddc=" << perf.iVDDC << "\n";
                }
            }

            if (getThrottle) {
                int status = -1;
                int flags = -1;
                int throttleRc = getThrottle(context, a.iAdapterIndex, &status, &flags);
                std::cout << "throttle_notification_rc=" << throttleRc << "\n";
                std::cout << "throttle_status=" << status << "\n";
                std::cout << "throttle_flags=" << flags << "\n";
            }

            if (getPMLog) {
                ADLPMLogDataOutput pm{};
                pm.size = static_cast<int>(sizeof(ADLPMLogDataOutput));
                int pmRc = getPMLog(context, a.iAdapterIndex, &pm);
                std::cout << "pmlog_query_rc=" << pmRc << "\n";
                if (pmRc == 0) {
                    for (const auto& sensor : interestingSensors) {
                        if (sensor.id >= 0 && sensor.id < ADL_PMLOG_MAX_SENSORS && pm.sensors[sensor.id].supported) {
                            std::cout << "pmlog_" << sensor.name << "=" << pm.sensors[sensor.id].value << "\n";
                        }
                    }
                }
            }

            if (getOd8Init) {
                ADLOD8InitSetting init{};
                init.count = OD8_COUNT;
                int initRc = getOd8Init(context, a.iAdapterIndex, &init);
                std::cout << "od8_init_rc=" << initRc << "\n";
                if (initRc == 0) {
                    std::cout << "od8_init_count=" << init.count << "\n";
                    std::cout << "od8_capabilities=0x" << std::hex << init.overdrive8Capabilities << std::dec << "\n";
                    for (const auto& setting : interestingOd8Settings) {
                        if (setting.id >= 0 && setting.id < OD8_COUNT) {
                            const auto& row = init.od8SettingTable[setting.id];
                            std::cout << "od8_init_" << setting.name
                                      << "_feature=" << row.featureID
                                      << "_min=" << row.minValue
                                      << "_max=" << row.maxValue
                                      << "_default=" << row.defaultValue << "\n";
                        }
                    }
                }
            }

            if (getOd8Current) {
                ADLOD8CurrentSetting current{};
                current.count = OD8_COUNT;
                int currentRc = getOd8Current(context, a.iAdapterIndex, &current);
                std::cout << "od8_current_rc=" << currentRc << "\n";
                if (currentRc == 0) {
                    std::cout << "od8_current_count=" << current.count << "\n";
                    for (const auto& setting : interestingOd8Settings) {
                        if (setting.id >= 0 && setting.id < OD8_COUNT) {
                            std::cout << "od8_current_" << setting.name << "=" << current.Od8SettingTable[setting.id] << "\n";
                        }
                    }
                }
            }
        }

        std::free(adapters);
    }

    int destroyRc = destroy(context);
    std::cout << "\nADL2_Main_Control_Destroy=" << destroyRc << "\n";
    return 0;
}
