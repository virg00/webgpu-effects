// Small helpers for reading WebGPU descriptor objects out of JS values.
#pragma once
#include <napi/native_api.h>
#include <cstdint>
#include <deque>
#include <string>
#include <vector>

namespace sg {

class Js {
public:
    explicit Js(napi_env env) : env(env) {}
    napi_env env;

    napi_valuetype type(napi_value v) const {
        napi_valuetype t = napi_undefined;
        if (v) napi_typeof(env, v, &t);
        return t;
    }
    bool nullish(napi_value v) const {
        napi_valuetype t = type(v);
        return t == napi_undefined || t == napi_null;
    }
    napi_value undefined() const { napi_value v; napi_get_undefined(env, &v); return v; }
    napi_value null() const { napi_value v; napi_get_null(env, &v); return v; }

    napi_value get(napi_value obj, const char *key) const {
        if (type(obj) != napi_object && type(obj) != napi_function) return nullptr;
        napi_value v = nullptr;
        napi_get_named_property(env, obj, key, &v);
        return nullish(v) ? nullptr : v;
    }
    bool has(napi_value obj, const char *key) const { return get(obj, key) != nullptr; }

    double num(napi_value v, double def = 0) const {
        if (!v) return def;
        napi_valuetype t = type(v);
        if (t == napi_number) { double d; napi_get_value_double(env, v, &d); return d; }
        if (t == napi_bigint) { int64_t i; bool lossless; napi_get_value_bigint_int64(env, v, &i, &lossless); return (double)i; }
        if (t == napi_boolean) { bool b; napi_get_value_bool(env, v, &b); return b ? 1 : 0; }
        return def;
    }
    uint32_t u32(napi_value v, uint32_t def = 0) const { return v ? (uint32_t)num(v, def) : def; }
    int32_t i32(napi_value v, int32_t def = 0) const { return v ? (int32_t)num(v, def) : def; }
    uint64_t u64(napi_value v, uint64_t def = 0) const {
        if (!v) return def;
        if (type(v) == napi_bigint) { uint64_t u; bool lossless; napi_get_value_bigint_uint64(env, v, &u, &lossless); return u; }
        return (uint64_t)num(v, (double)def);
    }
    bool boolean(napi_value v, bool def = false) const {
        if (!v) return def;
        bool b = def;
        if (type(v) == napi_boolean) napi_get_value_bool(env, v, &b);
        else b = num(v) != 0;
        return b;
    }
    std::string str(napi_value v, const std::string &def = "") const {
        if (!v || type(v) != napi_string) return def;
        size_t len = 0;
        napi_get_value_string_utf8(env, v, nullptr, 0, &len);
        std::string s(len, '\0');
        napi_get_value_string_utf8(env, v, s.data(), len + 1, &len);
        return s;
    }

    uint32_t fu32(napi_value o, const char *k, uint32_t def = 0) const { return u32(get(o, k), def); }
    uint64_t fu64(napi_value o, const char *k, uint64_t def = 0) const { return u64(get(o, k), def); }
    double fnum(napi_value o, const char *k, double def = 0) const { return num(get(o, k), def); }
    bool fbool(napi_value o, const char *k, bool def = false) const { return boolean(get(o, k), def); }
    std::string fstr(napi_value o, const char *k, const std::string &def = "") const { return str(get(o, k), def); }

    bool isArray(napi_value v) const {
        bool r = false;
        if (v) napi_is_array(env, v, &r);
        return r;
    }
    uint32_t length(napi_value arr) const {
        if (!arr) return 0;
        if (isArray(arr)) { uint32_t n = 0; napi_get_array_length(env, arr, &n); return n; }
        // Iterables such as Set / typed arrays: fall back to .length
        return u32(get(arr, "length"), 0);
    }
    napi_value at(napi_value arr, uint32_t i) const {
        napi_value v = nullptr;
        napi_get_element(env, arr, i, &v);
        return nullish(v) ? nullptr : v;
    }

    // GPU object handles: either a raw external, or a JS wrapper object carrying it in `_n`.
    template <typename T> T handle(napi_value v) const {
        if (!v) return nullptr;
        if (type(v) == napi_object) v = get(v, "_n");
        if (!v || type(v) != napi_external) return nullptr;
        void *p = nullptr;
        napi_get_value_external(env, v, &p);
        return (T)p;
    }

    // Raw bytes of an ArrayBuffer, TypedArray or DataView.
    bool bytes(napi_value v, uint8_t *&data, size_t &len) const {
        if (!v) return false;
        bool is = false;
        napi_is_arraybuffer(env, v, &is);
        if (is) { void *d; napi_get_arraybuffer_info(env, v, &d, &len); data = (uint8_t *)d; return true; }
        napi_is_typedarray(env, v, &is);
        if (is) {
            napi_typedarray_type t; size_t n; void *d; napi_value ab; size_t off;
            napi_get_typedarray_info(env, v, &t, &n, &d, &ab, &off);
            static const size_t sizes[] = {1, 1, 1, 2, 2, 4, 4, 4, 8, 8, 8};
            len = n * (t < 11 ? sizes[t] : 1);
            data = (uint8_t *)d;
            return true;
        }
        napi_is_dataview(env, v, &is);
        if (is) { void *d; napi_value ab; size_t off; napi_get_dataview_info(env, v, &len, &d, &ab, &off); data = (uint8_t *)d; return true; }
        return false;
    }

    napi_value mkNum(double d) const { napi_value v; napi_create_double(env, d, &v); return v; }
    napi_value mkBool(bool b) const { napi_value v; napi_get_boolean(env, b, &v); return v; }
    napi_value mkStr(const std::string &s) const { napi_value v; napi_create_string_utf8(env, s.data(), s.size(), &v); return v; }
    napi_value mkObj() const { napi_value v; napi_create_object(env, &v); return v; }
    napi_value mkArr() const { napi_value v; napi_create_array(env, &v); return v; }
    void set(napi_value o, const char *k, napi_value v) const { napi_set_named_property(env, o, k, v); }
    void push(napi_value arr, napi_value v) const { uint32_t n = length(arr); napi_set_element(env, arr, n, v); }

    void throwError(const std::string &msg) const { napi_throw_error(env, nullptr, msg.c_str()); }
};

// Keeps strings and arrays alive for the duration of one native call (WGPUStringView points into it).
class Arena {
public:
    const char *keep(std::string s) { strings.push_back(std::move(s)); return strings.back().c_str(); }
    template <typename T> T *array(size_t n) {
        blocks.emplace_back(n * sizeof(T) + 16, 0);
        return reinterpret_cast<T *>(blocks.back().data());
    }
    template <typename T> T *one() { return array<T>(1); }

private:
    std::deque<std::string> strings;
    std::deque<std::vector<uint8_t>> blocks;
};

struct Args {
    napi_value argv[12];
    size_t argc = 12;
    Args(napi_env env, napi_callback_info info) {
        napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
        for (size_t i = argc; i < 12; i++) argv[i] = nullptr;
        // Treat explicit undefined/null as absent
        Js js(env);
        for (size_t i = 0; i < argc; i++) if (js.nullish(argv[i])) argv[i] = nullptr;
    }
    napi_value operator[](size_t i) const { return i < 12 ? argv[i] : nullptr; }
};

} // namespace sg
