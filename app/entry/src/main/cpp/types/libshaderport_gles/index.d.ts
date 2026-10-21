export const nativeInit: (surfaceId: string, width: number, height: number) => boolean;
export const nativeSetShader: (fragmentSource: string, blockName: string, instanceName: string) => boolean;
export const nativeSetEffect: (fragments: string[], blocks: string[], instances: string[]) => boolean;
export const nativeSetParam: (name: string, values: number[]) => void;
export const nativeSetPointer: (x: number, y: number, active: number) => void;
export const nativeSetTime: (time: number, fixed: boolean) => void;
export const nativeCapture: (path: string) => boolean;
export const nativeCaptureReady: () => boolean;
/** "fps|cpuMs" */
export const nativeSetPaused: (paused: boolean) => void;
export const nativeSetRenderScale: (scale: number) => void;
export const nativeGetStats: () => string;
export const nativeResize: (width: number, height: number) => void;
export const nativeDispose: () => void;
