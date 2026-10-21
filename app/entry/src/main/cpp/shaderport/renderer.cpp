#include "renderer.h"

#include <EGL/eglext.h>
#include <hilog/log.h>
#include <native_buffer/buffer_common.h>

#include <cstdio>
#include <cstring>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x5301
#define LOG_TAG "ShaderPort"

namespace {

constexpr const char *kVertexShader = R"(#version 300 es
precision highp float;
layout(location = 0) in vec2 aPos;
smooth out vec2 _vs2fs_location0;
void main() {
    vec2 uv = aPos * 0.5 + 0.5;
    _vs2fs_location0 = vec2(uv.x, 1.0 - uv.y);
    gl_Position = vec4(aPos, 0.0, 1.0);
}
)";

constexpr const char *kBlitVertexShader = R"(#version 300 es
precision highp float;
layout(location = 0) in vec2 aPos;
out vec2 vUv;
void main() {
    vUv = aPos * 0.5 + 0.5;
    gl_Position = vec4(aPos, 0.0, 1.0);
}
)";

constexpr const char *kBlitFragmentShader = R"(#version 300 es
precision highp float;
in vec2 vUv;
uniform sampler2D uTex;
out vec4 fragColor;
void main() {
    fragColor = texture(uTex, vUv);
}
)";

GLuint CompileShader(GLenum type, const char *source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);
    GLint ok = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (ok != GL_TRUE) {
        char log[2048] = {0};
        glGetShaderInfoLog(shader, sizeof(log), nullptr, log);
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "compile failed: %{public}s", log);
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

}  // namespace

EffectRenderer &EffectRenderer::Get() {
    static EffectRenderer instance;
    return instance;
}

bool EffectRenderer::Init(uint64_t surfaceId, int width, int height) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (initialized_) {
        width_ = width;
        height_ = height;
        return true;
    }
    width_ = width;
    height_ = height;

    if (!CreateEgl(surfaceId)) {
        return false;
    }

    glGenVertexArrays(1, &vao_);
    glBindVertexArray(vao_);
    glGenBuffers(1, &vbo_);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_);
    const float quad[] = {-1.0f, -1.0f, 1.0f, -1.0f, -1.0f, 1.0f,
                          -1.0f, 1.0f,  1.0f, -1.0f, 1.0f,  1.0f};
    glBufferData(GL_ARRAY_BUFFER, sizeof(quad), quad, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), nullptr);
    glBindVertexArray(0);

    eglMakeCurrent(display_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);

    vsync_ = OH_NativeVSync_Create("shaderport", 11);
    if (vsync_ == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "vsync create failed");
        return false;
    }

    initialized_ = true;
    running_ = true;
    OH_NativeVSync_RequestFrame(vsync_, FrameCallback, this);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "EGL ready %{public}dx%{public}d", width_, height_);
    return true;
}

bool EffectRenderer::CreateEgl(uint64_t surfaceId) {
    if (OH_NativeWindow_CreateNativeWindowFromSurfaceId(surfaceId, &window_) != 0 || window_ == nullptr) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "native window create failed");
        return false;
    }

    // The shader writes sRGB-encoded values. Tag the window buffer as sRGB so devices whose
    // default surface is Display-P3 do not reinterpret the values (visible as a gamut shift).
    const int32_t colorSpaceResult = OH_NativeWindow_SetColorSpace(window_, OH_COLORSPACE_SRGB_FULL);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "window colorspace srgb ret=%{public}d",
                 colorSpaceResult);

    display_ = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (display_ == EGL_NO_DISPLAY || eglInitialize(display_, nullptr, nullptr) != EGL_TRUE) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "eglInitialize failed");
        return false;
    }

    const EGLint configAttribs[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT_KHR,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_NONE,
    };
    EGLint numConfigs = 0;
    if (eglChooseConfig(display_, configAttribs, &config_, 1, &numConfigs) != EGL_TRUE || numConfigs < 1) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "eglChooseConfig failed");
        return false;
    }

    const EGLint contextAttribs[] = {EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE};
    context_ = eglCreateContext(display_, config_, EGL_NO_CONTEXT, contextAttribs);
    if (context_ == EGL_NO_CONTEXT) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "eglCreateContext failed");
        return false;
    }

    surface_ = eglCreateWindowSurface(display_, config_,
                                      reinterpret_cast<EGLNativeWindowType>(window_), nullptr);
    if (surface_ == EGL_NO_SURFACE) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "eglCreateWindowSurface failed");
        return false;
    }

    // Ask EGL for an sRGB-tagged surface as well; harmless where the surface is already sRGB.
    eglSurfaceAttrib(display_, surface_, EGL_GL_COLORSPACE_KHR, EGL_GL_COLORSPACE_SRGB_KHR);

    if (eglMakeCurrent(display_, surface_, surface_, context_) != EGL_TRUE) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "eglMakeCurrent failed");
        return false;
    }
    eglSwapInterval(display_, 1);
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "GL_VERSION=%{public}s",
                 reinterpret_cast<const char *>(glGetString(GL_VERSION)));
    return true;
}

void EffectRenderer::SetShader(const std::string &fragmentSource, const std::string &blockName,
                               const std::string &instanceName) {
    SetEffect({fragmentSource}, {blockName}, {instanceName});
}

void EffectRenderer::SetEffect(const std::vector<std::string> &fragments,
                               const std::vector<std::string> &blocks,
                               const std::vector<std::string> &instances) {
    std::lock_guard<std::mutex> lock(mutex_);
    pendingFragments_ = fragments;
    pendingBlocks_ = blocks;
    pendingInstances_ = instances;
    hasPendingShader_ = true;
}

void EffectRenderer::SetParam(const std::string &name, const std::vector<float> &values) {
    std::lock_guard<std::mutex> lock(mutex_);
    params_[name] = values;
}

void EffectRenderer::SetPointer(float x, float y, float active) {
    std::lock_guard<std::mutex> lock(mutex_);
    const bool wasActive = pointerActive_ > 0.5f;
    pointerX_ = x < 0.0f ? 0.0f : (x > 1.0f ? 1.0f : x);
    pointerY_ = y < 0.0f ? 0.0f : (y > 1.0f ? 1.0f : y);
    pointerActive_ = active;
    if (!wasActive && active > 0.5f) {
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "pointer down %{public}f,%{public}f",
                     pointerX_, pointerY_);
    }
}

void EffectRenderer::SetFixedTime(double time, bool fixed) {
    std::lock_guard<std::mutex> lock(mutex_);
    fixedTime_ = time;
    useFixedTime_ = fixed;
}

void EffectRenderer::SetPaused(bool paused) {
    std::lock_guard<std::mutex> lock(mutex_);
    paused_ = paused;
}

void EffectRenderer::SetRenderScale(float scale) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (scale < 0.25f) {
        scale = 0.25f;
    }
    if (scale > 1.0f) {
        scale = 1.0f;
    }
    renderScale_ = scale;
}

void EffectRenderer::RequestCapture(const std::string &path) {
    std::lock_guard<std::mutex> lock(mutex_);
    capturePath_ = path;
    captureRequested_ = true;
    captureReady_.store(false);
}

void EffectRenderer::Resize(int width, int height) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (width > 0 && height > 0) {
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "resize %{public}dx%{public}d", width, height);
        width_ = width;
        height_ = height;
    }
}

void EffectRenderer::FrameCallback(long long timestamp, void *data) {
    auto *self = static_cast<EffectRenderer *>(data);
    if (self != nullptr) {
        self->OnFrame(timestamp);
    }
}

void EffectRenderer::OnFrame(long long timestamp) {
    if (!initialized_ || !running_) {
        return;
    }
    if (eglMakeCurrent(display_, surface_, surface_, context_) != EGL_TRUE) {
        return;
    }

    {
        std::lock_guard<std::mutex> lock(mutex_);
        if (firstTimestamp_ == 0) {
            firstTimestamp_ = timestamp;
        }
        const double frameSeconds =
            lastFrameTimestamp_ == 0 ? 0.0 : static_cast<double>(timestamp - lastFrameTimestamp_) / 1e9;
        lastFrameTimestamp_ = timestamp;

        double time = paused_ ? pausedTime_
                              : (useFixedTime_ ? fixedTime_
                                               : static_cast<double>(timestamp - firstTimestamp_) / 1e9);
        if (!paused_) {
            pausedTime_ = time;
        }
        if (hasPendingShader_) {
            BuildPrograms();
            hasPendingShader_ = false;
        }
        if (!programs_.empty()) {
            const auto renderStart = std::chrono::steady_clock::now();
            PackAndDraw(time);
            const auto renderEnd = std::chrono::steady_clock::now();
            const double cpuMs =
                std::chrono::duration<double, std::milli>(renderEnd - renderStart).count();

            if (frameSeconds > 0.0001) {
                const double instantFps = 1.0 / frameSeconds;
                fps_ = fps_ == 0.0 ? instantFps : fps_ * 0.9 + instantFps * 0.1;
                cpuMs_ = cpuMs_ == 0.0 ? cpuMs : cpuMs_ * 0.9 + cpuMs * 0.1;
            }

            if (captureRequested_ && !capturePath_.empty()) {
                CaptureFrame();
            }
        }
    }

    eglSwapBuffers(display_, surface_);
    eglMakeCurrent(display_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);

    if (running_) {
        OH_NativeVSync_RequestFrame(vsync_, FrameCallback, this);
    }
}

bool EffectRenderer::BuildPrograms() {
    DestroyPrograms();
    const size_t count = pendingFragments_.size();
    if (count == 0) {
        return false;
    }
    programs_.reserve(count);
    for (size_t i = 0; i < count; ++i) {
        const std::string block = i < pendingBlocks_.size() ? pendingBlocks_[i] : "combined_block_0Fragment";
        const std::string instance =
            i < pendingInstances_.size() ? pendingInstances_[i] : "_group_0_binding_0_fs";
        ProgramState state;
        if (!BuildOne(state, pendingFragments_[i], block, instance)) {
            if (state.program != 0) {
                glDeleteProgram(state.program);
            }
            if (state.ubo != 0) {
                glDeleteBuffers(1, &state.ubo);
            }
            DestroyPrograms();
            return false;
        }
        programs_.push_back(state);
    }
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "effect built: %{public}zu pass(es)", count);
    return true;
}

bool EffectRenderer::BuildOne(ProgramState &state, const std::string &fragment, const std::string &block,
                              const std::string &instance) {
    GLuint vs = CompileShader(GL_VERTEX_SHADER, kVertexShader);
    GLuint fs = CompileShader(GL_FRAGMENT_SHADER, fragment.c_str());
    if (vs == 0 || fs == 0) {
        if (vs != 0) glDeleteShader(vs);
        if (fs != 0) glDeleteShader(fs);
        return false;
    }

    GLuint program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);
    glDeleteShader(vs);
    glDeleteShader(fs);

    GLint linked = GL_FALSE;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (linked != GL_TRUE) {
        char log[2048] = {0};
        glGetProgramInfoLog(program, sizeof(log), nullptr, log);
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "link failed: %{public}s", log);
        glDeleteProgram(program);
        return false;
    }
    state.program = program;
    ReflectUbo(state, block, instance);
    return true;
}

void EffectRenderer::ReflectUbo(ProgramState &state, const std::string &blockName,
                                const std::string &instanceName) {
    state.members.clear();
    state.uboSize = 0;
    state.blockIndex = glGetUniformBlockIndex(state.program, blockName.c_str());

    if (state.blockIndex == GL_INVALID_INDEX) {
        GLint blockCount = 0;
        glGetProgramiv(state.program, GL_ACTIVE_UNIFORM_BLOCKS, &blockCount);
        for (GLint i = 0; i < blockCount; ++i) {
            char name[256] = {0};
            glGetActiveUniformBlockName(state.program, static_cast<GLuint>(i), sizeof(name), nullptr, name);
            if (blockName == name) {
                state.blockIndex = static_cast<GLuint>(i);
                break;
            }
        }
    }
    if (state.blockIndex == GL_INVALID_INDEX) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "uniform block '%{public}s' not found",
                     blockName.c_str());
        return;
    }

    glGetActiveUniformBlockiv(state.program, state.blockIndex, GL_UNIFORM_BLOCK_DATA_SIZE, &state.uboSize);
    glUniformBlockBinding(state.program, state.blockIndex, 0);

    glGenBuffers(1, &state.ubo);
    glBindBuffer(GL_UNIFORM_BUFFER, state.ubo);
    glBufferData(GL_UNIFORM_BUFFER, state.uboSize, nullptr, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, state.ubo);

    const std::string prefix = instanceName + ".";
    GLint uniformCount = 0;
    glGetProgramiv(state.program, GL_ACTIVE_UNIFORMS, &uniformCount);
    for (GLint i = 0; i < uniformCount; ++i) {
        char name[256] = {0};
        GLint size = 0;
        GLenum type = GL_FLOAT;
        glGetActiveUniform(state.program, static_cast<GLuint>(i), sizeof(name), nullptr, &size, &type, name);
        std::string full(name);
        if (type == GL_SAMPLER_2D) {
            glUseProgram(state.program);
            glUniform1i(glGetUniformLocation(state.program, name), 0);
            continue;
        }
        if (full.compare(0, prefix.size(), prefix) != 0) {
            continue;
        }
        GLint offset = 0;
        GLint stride = 0;
        GLuint index = static_cast<GLuint>(i);
        glGetActiveUniformsiv(state.program, 1, &index, GL_UNIFORM_OFFSET, &offset);
        glGetActiveUniformsiv(state.program, 1, &index, GL_UNIFORM_ARRAY_STRIDE, &stride);
        // Array uniforms report "name[0]"; the spec stores the base path.
        std::string memberPath = full.substr(prefix.size());
        const size_t bracket = memberPath.find("[0]");
        if (bracket != std::string::npos) {
            memberPath.erase(bracket, 3);
        }
        state.members.push_back({memberPath, type, offset, size, stride});
    }
}

void EffectRenderer::DestroyPrograms() {
    for (auto &state : programs_) {
        if (state.program != 0) glDeleteProgram(state.program);
        if (state.ubo != 0) glDeleteBuffers(1, &state.ubo);
    }
    programs_.clear();
}

void EffectRenderer::EnsureRttTargets(int width, int height) {
    if (width <= 0 || height <= 0) {
        return;
    }
    if (rttWidth_ == width && rttHeight_ == height && rttFbo_[0] != 0 && rttFbo_[1] != 0) {
        return;
    }
    for (int i = 0; i < 2; ++i) {
        if (rttTex_[i] == 0) {
            glGenTextures(1, &rttTex_[i]);
        }
        glBindTexture(GL_TEXTURE_2D, rttTex_[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);

        if (rttFbo_[i] == 0) {
            glGenFramebuffers(1, &rttFbo_[i]);
        }
        glBindFramebuffer(GL_FRAMEBUFFER, rttFbo_[i]);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rttTex_[i], 0);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    rttWidth_ = width;
    rttHeight_ = height;
}

void EffectRenderer::DestroyRttTargets() {
    for (int i = 0; i < 2; ++i) {
        if (rttFbo_[i] != 0) {
            glDeleteFramebuffers(1, &rttFbo_[i]);
            rttFbo_[i] = 0;
        }
        if (rttTex_[i] != 0) {
            glDeleteTextures(1, &rttTex_[i]);
            rttTex_[i] = 0;
        }
    }
    rttWidth_ = 0;
    rttHeight_ = 0;
}

void EffectRenderer::EnsureOutputTarget(int width, int height) {
    if (outWidth_ == width && outHeight_ == height && outFbo_ != 0) {
        return;
    }
    if (outTex_ == 0) {
        glGenTextures(1, &outTex_);
    }
    glBindTexture(GL_TEXTURE_2D, outTex_);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);

    if (outFbo_ == 0) {
        glGenFramebuffers(1, &outFbo_);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, outFbo_);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, outTex_, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    outWidth_ = width;
    outHeight_ = height;
}

void EffectRenderer::DestroyOutputTarget() {
    if (outFbo_ != 0) {
        glDeleteFramebuffers(1, &outFbo_);
        outFbo_ = 0;
    }
    if (outTex_ != 0) {
        glDeleteTextures(1, &outTex_);
        outTex_ = 0;
    }
    outWidth_ = 0;
    outHeight_ = 0;
}

bool EffectRenderer::EnsureBlit() {
    if (blitProgram_ != 0) {
        return true;
    }
    GLuint vs = CompileShader(GL_VERTEX_SHADER, kBlitVertexShader);
    GLuint fs = CompileShader(GL_FRAGMENT_SHADER, kBlitFragmentShader);
    if (vs == 0 || fs == 0) {
        if (vs != 0) glDeleteShader(vs);
        if (fs != 0) glDeleteShader(fs);
        return false;
    }
    GLuint program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);
    glDeleteShader(vs);
    glDeleteShader(fs);
    GLint linked = GL_FALSE;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (linked != GL_TRUE) {
        glDeleteProgram(program);
        return false;
    }
    blitProgram_ = program;
    glUseProgram(blitProgram_);
    blitSampler_ = glGetUniformLocation(blitProgram_, "uTex");
    glUniform1i(blitSampler_, 0);
    return true;
}

void EffectRenderer::PackAndDraw(double time) {
    const int count = static_cast<int>(programs_.size());
    if (count == 0) {
        return;
    }

    int renderWidth = static_cast<int>(static_cast<float>(width_) * renderScale_ + 0.5f);
    int renderHeight = static_cast<int>(static_cast<float>(height_) * renderScale_ + 0.5f);
    if (renderWidth < 1) {
        renderWidth = 1;
    }
    if (renderHeight < 1) {
        renderHeight = 1;
    }
    const bool scaled = (renderWidth != width_ || renderHeight != height_);

    if (count > 1) {
        EnsureRttTargets(renderWidth, renderHeight);
    }
    if (scaled) {
        EnsureOutputTarget(renderWidth, renderHeight);
    }

    for (int i = 0; i < count; ++i) {
        const ProgramState &state = programs_[i];
        if (state.program == 0) {
            continue;
        }
        const bool isFinal = (i == count - 1);
        const GLuint target = isFinal ? (scaled ? outFbo_ : 0) : rttFbo_[i % 2];
        glBindFramebuffer(GL_FRAMEBUFFER, target);
        glViewport(0, 0, renderWidth, renderHeight);
        if (isFinal) {
            glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        } else {
            glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        }
        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(state.program);
        PackProgram(state, time, renderWidth, renderHeight);
        glBindBufferBase(GL_UNIFORM_BUFFER, 0, state.ubo);

        if (i > 0) {
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, rttTex_[(i - 1) % 2]);
        }

        glBindVertexArray(vao_);
        glDrawArrays(GL_TRIANGLES, 0, 6);
    }

    if (scaled) {
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glViewport(0, 0, width_, height_);
        if (EnsureBlit()) {
            glUseProgram(blitProgram_);
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, outTex_);
            glBindVertexArray(vao_);
            glDrawArrays(GL_TRIANGLES, 0, 6);
        }
    }

    glBindVertexArray(0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void EffectRenderer::PackProgram(const ProgramState &state, double time, int viewWidth, int viewHeight) {
    std::vector<uint8_t> buffer(static_cast<size_t>(state.uboSize), 0);
    const float vw = static_cast<float>(viewWidth);
    const float vh = static_cast<float>(viewHeight);
    const float aspect = vh > 0.0f ? vw / vh : 1.0f;

    for (const auto &member : state.members) {
        if (member.size > 1) {
            // Arrays (colour stops, converted colours) come from spec.resolved as a flat list.
            const auto array = params_.find(member.path);
            if (array != params_.end()) {
                WriteArray(buffer, member, array->second);
            }
            continue;
        }
        const size_t dot = member.path.find('.');
        const std::string node = dot == std::string::npos ? member.path : member.path.substr(0, dot);
        const std::string leaf = dot == std::string::npos ? std::string() : member.path.substr(dot + 1);

        std::vector<float> values;
        if (node == "_sys") {
            if (leaf == "time") values = {static_cast<float>(time)};
            else if (leaf == "viewportSize") values = {vw, vh};
            else if (leaf == "logicalViewportSize") values = {vw, vh};
            else if (leaf == "aspect") values = {aspect};
            else if (leaf == "pointer") values = {pointerX_, pointerY_};
            else if (leaf == "pointerActive") values = {pointerActive_};
        } else if (node == "n_root") {
            if (leaf == "_opacity") values = {1.0f};
        } else if (node == "n_n" || node == "n_base") {
            if (leaf == "_opacity") {
                values = {1.0f};
            } else if (leaf == "_animTime") {
                values = {static_cast<float>(time)};
            } else {
                // Parameters are addressed by their full UBO path (e.g. "n_n.intensity",
                // "n_base.colorA") because composite effects populate two nodes. Resolved
                // values (including stopCount) take precedence over the empty default.
                const auto it = params_.find(member.path);
                if (it != params_.end()) {
                    values = it->second;
                } else if (leaf == "stopCount") {
                    values = {0.0f};
                }
            }
        }
        WriteValue(buffer, member, values);
    }

    glBindBuffer(GL_UNIFORM_BUFFER, state.ubo);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, static_cast<GLsizeiptr>(buffer.size()), buffer.data());
}

void EffectRenderer::WriteValue(std::vector<uint8_t> &buffer, const UboMember &member,
                                const std::vector<float> &values) const {
    if (values.empty() || member.offset < 0) {
        return;
    }
    const size_t offset = static_cast<size_t>(member.offset);
    const size_t bytes = buffer.size();
    auto putFloat = [&](size_t index, float value) {
        if (offset + index * sizeof(float) + sizeof(float) <= bytes) {
            std::memcpy(buffer.data() + offset + index * sizeof(float), &value, sizeof(float));
        }
    };

    switch (member.type) {
        case GL_FLOAT:
            putFloat(0, values[0]);
            break;
        case GL_FLOAT_VEC2:
            for (int i = 0; i < 2; ++i) putFloat(i, i < static_cast<int>(values.size()) ? values[i] : 0.0f);
            break;
        case GL_FLOAT_VEC3:
            for (int i = 0; i < 3; ++i) putFloat(i, i < static_cast<int>(values.size()) ? values[i] : 0.0f);
            break;
        case GL_FLOAT_VEC4:
            for (int i = 0; i < 4; ++i) putFloat(i, i < static_cast<int>(values.size()) ? values[i] : 0.0f);
            break;
        case GL_INT:
        case GL_BOOL: {
            GLint v = static_cast<GLint>(values[0]);
            if (offset + sizeof(v) <= bytes) std::memcpy(buffer.data() + offset, &v, sizeof(v));
            break;
        }
        default:
            break;
    }
}

void EffectRenderer::WriteArray(std::vector<uint8_t> &buffer, const UboMember &member,
                                const std::vector<float> &values) const {
    int components = 1;
    switch (member.type) {
        case GL_FLOAT_VEC4:
            components = 4;
            break;
        case GL_FLOAT_VEC3:
            components = 3;
            break;
        case GL_FLOAT_VEC2:
            components = 2;
            break;
        default:
            components = 1;
            break;
    }
    const size_t stride = member.arrayStride > 0
                              ? static_cast<size_t>(member.arrayStride)
                              : static_cast<size_t>(components) * sizeof(float);
    for (GLint element = 0; element < member.size; ++element) {
        for (int c = 0; c < components; ++c) {
            const size_t index = static_cast<size_t>(element) * components + c;
            const float value = index < values.size() ? values[index] : 0.0f;
            const size_t offset = static_cast<size_t>(member.offset) +
                                  static_cast<size_t>(element) * stride + c * sizeof(float);
            if (offset + sizeof(float) <= buffer.size()) {
                std::memcpy(buffer.data() + offset, &value, sizeof(float));
            }
        }
    }
}

void EffectRenderer::CaptureFrame() {
    if (width_ <= 0 || height_ <= 0) {
        captureRequested_ = false;
        captureReady_.store(true);
        return;
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    const size_t pixelBytes = static_cast<size_t>(width_) * static_cast<size_t>(height_) * 4;
    std::vector<uint8_t> pixels(pixelBytes, 0);
    glReadPixels(0, 0, width_, height_, GL_RGBA, GL_UNSIGNED_BYTE, pixels.data());

    FILE *file = std::fopen(capturePath_.c_str(), "wb");
    if (file != nullptr) {
        const uint32_t header[2] = {static_cast<uint32_t>(width_), static_cast<uint32_t>(height_)};
        std::fwrite(header, sizeof(uint32_t), 2, file);
        std::fwrite(pixels.data(), 1, pixels.size(), file);
        std::fclose(file);
        OH_LOG_Print(LOG_APP, LOG_INFO, LOG_DOMAIN, LOG_TAG, "capture %{public}s %{public}dx%{public}d",
                     capturePath_.c_str(), width_, height_);
    } else {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_DOMAIN, LOG_TAG, "capture open failed: %{public}s",
                     capturePath_.c_str());
    }
    captureRequested_ = false;
    captureReady_.store(true);
}

std::string EffectRenderer::StatsText() {
    std::lock_guard<std::mutex> lock(mutex_);
    char buffer[64] = {0};
    std::snprintf(buffer, sizeof(buffer), "%.1f|%.2f", fps_, cpuMs_);
    return std::string(buffer);
}

void EffectRenderer::Dispose() {
    running_ = false;
    if (vsync_ != nullptr) {
        OH_NativeVSync_Destroy(vsync_);
        vsync_ = nullptr;
    }

    std::lock_guard<std::mutex> lock(mutex_);
    if (display_ != EGL_NO_DISPLAY && context_ != EGL_NO_CONTEXT) {
        eglMakeCurrent(display_, surface_, surface_, context_);
        DestroyPrograms();
        DestroyRttTargets();
        DestroyOutputTarget();
        if (blitProgram_ != 0) {
            glDeleteProgram(blitProgram_);
            blitProgram_ = 0;
        }
        if (vbo_ != 0) glDeleteBuffers(1, &vbo_);
        if (vao_ != 0) glDeleteVertexArrays(1, &vao_);
        vbo_ = 0;
        vao_ = 0;
        eglMakeCurrent(display_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        eglDestroySurface(display_, surface_);
        eglDestroyContext(display_, context_);
        eglTerminate(display_);
    }
    surface_ = EGL_NO_SURFACE;
    context_ = EGL_NO_CONTEXT;
    display_ = EGL_NO_DISPLAY;

    if (window_ != nullptr) {
        OH_NativeWindow_DestroyNativeWindow(window_);
        window_ = nullptr;
    }
    initialized_ = false;
}
