#include <napi/native_api.h>

#include <string>
#include <vector>

#include "renderer.h"

namespace {

std::string GetString(napi_env env, napi_value value) {
    size_t length = 0;
    napi_get_value_string_utf8(env, value, nullptr, 0, &length);
    std::string result(length + 1, '\0');
    napi_get_value_string_utf8(env, value, &result[0], length + 1, &length);
    result.resize(length);
    return result;
}

napi_value MakeBoolean(napi_env env, bool value) {
    napi_value result = nullptr;
    napi_get_boolean(env, value, &result);
    return result;
}

napi_value MakeUndefined(napi_env env) {
    napi_value result = nullptr;
    napi_get_undefined(env, &result);
    return result;
}

std::vector<std::string> GetStringArray(napi_env env, napi_value value) {
    std::vector<std::string> out;
    bool isArray = false;
    napi_is_array(env, value, &isArray);
    if (!isArray) {
        return out;
    }
    uint32_t length = 0;
    napi_get_array_length(env, value, &length);
    out.reserve(length);
    for (uint32_t i = 0; i < length; ++i) {
        napi_value element = nullptr;
        napi_get_element(env, value, i, &element);
        out.push_back(GetString(env, element));
    }
    return out;
}

napi_value NativeInit(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 3) {
        return MakeBoolean(env, false);
    }

    const std::string surfaceIdText = GetString(env, args[0]);
    int32_t width = 0;
    int32_t height = 0;
    napi_get_value_int32(env, args[1], &width);
    napi_get_value_int32(env, args[2], &height);

    uint64_t surfaceId = 0;
    try {
        surfaceId = std::stoull(surfaceIdText);
    } catch (...) {
        return MakeBoolean(env, false);
    }

    return MakeBoolean(env, EffectRenderer::Get().Init(surfaceId, width, height));
}

napi_value NativeSetShader(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 3) {
        return MakeBoolean(env, false);
    }
    const std::string fragment = GetString(env, args[0]);
    const std::string block = GetString(env, args[1]);
    const std::string instance = GetString(env, args[2]);
    EffectRenderer::Get().SetShader(fragment, block, instance);
    return MakeBoolean(env, true);
}

napi_value NativeSetEffect(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 3) {
        return MakeBoolean(env, false);
    }
    const std::vector<std::string> fragments = GetStringArray(env, args[0]);
    const std::vector<std::string> blocks = GetStringArray(env, args[1]);
    const std::vector<std::string> instances = GetStringArray(env, args[2]);
    if (fragments.empty()) {
        return MakeBoolean(env, false);
    }
    EffectRenderer::Get().SetEffect(fragments, blocks, instances);
    return MakeBoolean(env, true);
}

napi_value NativeSetParam(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 2) {
        return MakeUndefined(env);
    }

    const std::string name = GetString(env, args[0]);
    bool isArray = false;
    napi_is_array(env, args[1], &isArray);
    std::vector<float> values;
    if (isArray) {
        uint32_t length = 0;
        napi_get_array_length(env, args[1], &length);
        values.reserve(length);
        for (uint32_t i = 0; i < length; ++i) {
            napi_value element = nullptr;
            napi_get_element(env, args[1], i, &element);
            double value = 0.0;
            napi_get_value_double(env, element, &value);
            values.push_back(static_cast<float>(value));
        }
    }
    EffectRenderer::Get().SetParam(name, values);
    return MakeUndefined(env);
}

napi_value NativeSetPointer(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 3) {
        return MakeUndefined(env);
    }
    double x = 0.5;
    double y = 0.5;
    double active = 0.0;
    napi_get_value_double(env, args[0], &x);
    napi_get_value_double(env, args[1], &y);
    napi_get_value_double(env, args[2], &active);
    EffectRenderer::Get().SetPointer(static_cast<float>(x), static_cast<float>(y), static_cast<float>(active));
    return MakeUndefined(env);
}

napi_value NativeSetTime(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 2) {
        return MakeUndefined(env);
    }
    double time = 0.0;
    bool fixed = true;
    napi_get_value_double(env, args[0], &time);
    napi_get_value_bool(env, args[1], &fixed);
    EffectRenderer::Get().SetFixedTime(time, fixed);
    return MakeUndefined(env);
}

napi_value NativeCapture(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 1) {
        return MakeBoolean(env, false);
    }
    EffectRenderer::Get().RequestCapture(GetString(env, args[0]));
    return MakeBoolean(env, true);
}

napi_value NativeCaptureReady(napi_env env, napi_callback_info info) {
    (void)info;
    return MakeBoolean(env, EffectRenderer::Get().CaptureReady());
}

napi_value NativeResize(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 2) {
        return MakeUndefined(env);
    }
    int32_t width = 0;
    int32_t height = 0;
    napi_get_value_int32(env, args[0], &width);
    napi_get_value_int32(env, args[1], &height);
    EffectRenderer::Get().Resize(width, height);
    return MakeUndefined(env);
}

napi_value NativeSetPaused(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 1) {
        return MakeUndefined(env);
    }
    bool paused = false;
    napi_get_value_bool(env, args[0], &paused);
    EffectRenderer::Get().SetPaused(paused);
    return MakeUndefined(env);
}

napi_value NativeSetRenderScale(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (argc < 1) {
        return MakeUndefined(env);
    }
    double scale = 1.0;
    napi_get_value_double(env, args[0], &scale);
    EffectRenderer::Get().SetRenderScale(static_cast<float>(scale));
    return MakeUndefined(env);
}

napi_value NativeGetStats(napi_env env, napi_callback_info info) {
    (void)info;
    const std::string stats = EffectRenderer::Get().StatsText();
    napi_value result = nullptr;
    napi_create_string_utf8(env, stats.c_str(), stats.size(), &result);
    return result;
}

napi_value NativeDispose(napi_env env, napi_callback_info info) {
    (void)env;
    (void)info;
    EffectRenderer::Get().Dispose();
    return MakeUndefined(env);
}

}  // namespace

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"nativeInit", nullptr, NativeInit, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativeSetShader", nullptr, NativeSetShader, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativeSetEffect", nullptr, NativeSetEffect, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativeSetParam", nullptr, NativeSetParam, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativeSetPointer", nullptr, NativeSetPointer, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativeSetTime", nullptr, NativeSetTime, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativeCapture", nullptr, NativeCapture, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativeCaptureReady", nullptr, NativeCaptureReady, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativeSetPaused", nullptr, NativeSetPaused, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativeSetRenderScale", nullptr, NativeSetRenderScale, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativeGetStats", nullptr, NativeGetStats, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativeResize", nullptr, NativeResize, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"nativeDispose", nullptr, NativeDispose, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module shaderportModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "shaderport_gles",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) {
    napi_module_register(&shaderportModule);
}
