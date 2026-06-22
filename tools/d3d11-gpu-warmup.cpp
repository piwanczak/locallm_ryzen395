#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <d3d11.h>

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <iostream>

static void releaseIf(void* p) {
    if (p) {
        static_cast<IUnknown*>(p)->Release();
    }
}

int main(int argc, char** argv) {
    int seconds = 30;
    if (argc > 1) {
        seconds = std::max(1, std::atoi(argv[1]));
    }

    D3D_FEATURE_LEVEL levels[] = {
        D3D_FEATURE_LEVEL_11_1,
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1,
        D3D_FEATURE_LEVEL_10_0,
    };

    ID3D11Device* device = nullptr;
    ID3D11DeviceContext* context = nullptr;
    D3D_FEATURE_LEVEL selected = D3D_FEATURE_LEVEL_10_0;
    HRESULT hr = D3D11CreateDevice(
        nullptr,
        D3D_DRIVER_TYPE_HARDWARE,
        nullptr,
        0,
        levels,
        ARRAYSIZE(levels),
        D3D11_SDK_VERSION,
        &device,
        &selected,
        &context);
    if (FAILED(hr)) {
        std::cerr << "D3D11CreateDevice failed: 0x" << std::hex << hr << std::dec << "\n";
        return 2;
    }

    D3D11_TEXTURE2D_DESC texDesc{};
    texDesc.Width = 8192;
    texDesc.Height = 8192;
    texDesc.MipLevels = 1;
    texDesc.ArraySize = 1;
    texDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    texDesc.SampleDesc.Count = 1;
    texDesc.Usage = D3D11_USAGE_DEFAULT;
    texDesc.BindFlags = D3D11_BIND_RENDER_TARGET;

    ID3D11Texture2D* texture = nullptr;
    hr = device->CreateTexture2D(&texDesc, nullptr, &texture);
    if (FAILED(hr)) {
        std::cerr << "CreateTexture2D failed: 0x" << std::hex << hr << std::dec << "\n";
        releaseIf(context);
        releaseIf(device);
        return 3;
    }

    ID3D11RenderTargetView* rtv = nullptr;
    hr = device->CreateRenderTargetView(texture, nullptr, &rtv);
    if (FAILED(hr)) {
        std::cerr << "CreateRenderTargetView failed: 0x" << std::hex << hr << std::dec << "\n";
        releaseIf(texture);
        releaseIf(context);
        releaseIf(device);
        return 4;
    }

    D3D11_QUERY_DESC queryDesc{};
    queryDesc.Query = D3D11_QUERY_EVENT;
    ID3D11Query* query = nullptr;
    hr = device->CreateQuery(&queryDesc, &query);
    if (FAILED(hr)) {
        std::cerr << "CreateQuery failed: 0x" << std::hex << hr << std::dec << "\n";
        releaseIf(rtv);
        releaseIf(texture);
        releaseIf(context);
        releaseIf(device);
        return 5;
    }

    auto start = std::chrono::steady_clock::now();
    auto deadline = start + std::chrono::seconds(seconds);
    unsigned long long clears = 0;

    while (std::chrono::steady_clock::now() < deadline) {
        float color[4] = {
            static_cast<float>((clears & 255) / 255.0),
            static_cast<float>(((clears >> 8) & 255) / 255.0),
            static_cast<float>(((clears >> 16) & 255) / 255.0),
            1.0f,
        };
        context->ClearRenderTargetView(rtv, color);
        ++clears;

        if ((clears & 63ULL) == 0) {
            context->End(query);
            while (context->GetData(query, nullptr, 0, 0) == S_FALSE) {
                Sleep(0);
            }
        }
    }

    context->Flush();
    std::cout << "seconds=" << seconds << "\n";
    std::cout << "feature_level=0x" << std::hex << selected << std::dec << "\n";
    std::cout << "clears=" << clears << "\n";

    releaseIf(query);
    releaseIf(rtv);
    releaseIf(texture);
    releaseIf(context);
    releaseIf(device);
    return 0;
}
