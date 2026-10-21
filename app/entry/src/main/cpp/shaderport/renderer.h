#ifndef SHADERPORT_RENDERER_H
#define SHADERPORT_RENDERER_H

#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <native_vsync/native_vsync.h>
#include <native_window/external_window.h>

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

struct UboMember {
    std::string path;  // e.g. "n_n.colorA"
    GLenum type = GL_FLOAT;
    GLint offset = 0;
    GLint size = 1;
    GLint arrayStride = 0;
};

struct ProgramState {
    GLuint program = 0;
    GLuint ubo = 0;
    GLuint blockIndex = GL_INVALID_INDEX;
    GLint uboSize = 0;
    std::vector<UboMember> members;
};

class EffectRenderer {
public:
    static EffectRenderer &Get();

    bool Init(uint64_t surfaceId, int width, int height);
    /** Single-pass convenience wrapper. */
    void SetShader(const std::string &fragmentSource, const std::string &blockName,
                   const std::string &instanceName);
    /** Multi-pass: index order, last pass renders to the screen. */
    void SetEffect(const std::vector<std::string> &fragments, const std::vector<std::string> &blocks,
                   const std::vector<std::string> &instances);
    void SetParam(const std::string &name, const std::vector<float> &values);
    void SetPointer(float x, float y, float active);
    void SetFixedTime(double time, bool fixed);
    void SetPaused(bool paused);
    /** 0.25..1.0 — render the effect chain at a lower resolution and upsample to the screen. */
    void SetRenderScale(float scale);
    void RequestCapture(const std::string &path);
    bool CaptureReady() const { return captureReady_.load(); }
    void Resize(int width, int height);
    void Dispose();
    /** "fps|cpuMs" — display-limited FPS and the EMA of the CPU submit time. */
    std::string StatsText();

private:
    EffectRenderer() = default;
    ~EffectRenderer() = default;

    static void FrameCallback(long long timestamp, void *data);
    void OnFrame(long long timestamp);

    bool CreateEgl(uint64_t surfaceId);
    bool BuildPrograms();
    bool BuildOne(ProgramState &state, const std::string &fragment, const std::string &block,
                  const std::string &instance);
    void ReflectUbo(ProgramState &state, const std::string &blockName, const std::string &instanceName);
    void DestroyPrograms();
    void EnsureRttTargets(int width, int height);
    void DestroyRttTargets();
    void EnsureOutputTarget(int width, int height);
    void DestroyOutputTarget();
    bool EnsureBlit();
    void PackAndDraw(double time);
    void PackProgram(const ProgramState &state, double time, int viewWidth, int viewHeight);
    void WriteValue(std::vector<uint8_t> &buffer, const UboMember &member,
                    const std::vector<float> &values) const;
    void WriteArray(std::vector<uint8_t> &buffer, const UboMember &member,
                    const std::vector<float> &values) const;
    void CaptureFrame();

    EGLDisplay display_ = EGL_NO_DISPLAY;
    EGLSurface surface_ = EGL_NO_SURFACE;
    EGLContext context_ = EGL_NO_CONTEXT;
    EGLConfig config_ = nullptr;
    OHNativeWindow *window_ = nullptr;
    OH_NativeVSync *vsync_ = nullptr;

    GLuint vao_ = 0;
    GLuint vbo_ = 0;
    std::vector<ProgramState> programs_;

    GLuint rttTex_[2] = {0, 0};
    GLuint rttFbo_[2] = {0, 0};
    int rttWidth_ = 0;
    int rttHeight_ = 0;

    GLuint outTex_ = 0;
    GLuint outFbo_ = 0;
    int outWidth_ = 0;
    int outHeight_ = 0;
    GLuint blitProgram_ = 0;
    GLint blitSampler_ = -1;
    float renderScale_ = 1.0f;

    std::mutex mutex_;
    std::unordered_map<std::string, std::vector<float>> params_;
    std::vector<std::string> pendingFragments_;
    std::vector<std::string> pendingBlocks_;
    std::vector<std::string> pendingInstances_;
    bool hasPendingShader_ = false;

    int width_ = 0;
    int height_ = 0;
    float pointerX_ = 0.5f;
    float pointerY_ = 0.5f;
    float pointerActive_ = 0.0f;

    bool useFixedTime_ = false;
    double fixedTime_ = 0.0;
    bool paused_ = false;
    double pausedTime_ = 0.0;
    std::string capturePath_;
    bool captureRequested_ = false;
    std::atomic<bool> captureReady_{false};

    bool running_ = false;
    bool initialized_ = false;
    long long firstTimestamp_ = 0;
    long long lastFrameTimestamp_ = 0;
    double fps_ = 0.0;
    double cpuMs_ = 0.0;
};

#endif  // SHADERPORT_RENDERER_H
