'use client';
import { forwardRef, useEffect, useImperativeHandle, useRef } from 'react';

export type SignaturePadHandle = {
  toDataURL: () => string | null;
  clear: () => void;
  isEmpty: () => boolean;
};

const SignaturePad = forwardRef<SignaturePadHandle, { className?: string }>(
  function SignaturePad({ className }, ref) {
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const drawingRef = useRef(false);
    const lastRef = useRef<{ x: number; y: number } | null>(null);
    const dirtyRef = useRef(false);

    const reset = () => {
      const c = canvasRef.current;
      if (!c) return;
      const ctx = c.getContext('2d')!;
      const rect = c.getBoundingClientRect();
      ctx.fillStyle = '#fff';
      ctx.fillRect(0, 0, rect.width, rect.height);
      dirtyRef.current = false;
    };

    useImperativeHandle(ref, () => ({
      toDataURL: () => {
        if (!canvasRef.current || !dirtyRef.current) return null;
        return canvasRef.current.toDataURL('image/png');
      },
      clear: reset,
      isEmpty: () => !dirtyRef.current,
    }));

    useEffect(() => {
      const c = canvasRef.current;
      if (!c) return;
      const dpr = window.devicePixelRatio || 1;
      const rect = c.getBoundingClientRect();
      c.width = rect.width * dpr;
      c.height = rect.height * dpr;
      const ctx = c.getContext('2d')!;
      ctx.scale(dpr, dpr);
      ctx.fillStyle = '#fff';
      ctx.fillRect(0, 0, rect.width, rect.height);
      ctx.lineWidth = 2;
      ctx.lineCap = 'round';
      ctx.strokeStyle = '#0f172a';
    }, []);

    const point = (e: React.PointerEvent) => {
      const rect = canvasRef.current!.getBoundingClientRect();
      return { x: e.clientX - rect.left, y: e.clientY - rect.top };
    };

    const down = (e: React.PointerEvent) => {
      e.preventDefault();
      drawingRef.current = true;
      lastRef.current = point(e);
      canvasRef.current?.setPointerCapture(e.pointerId);
    };

    const move = (e: React.PointerEvent) => {
      if (!drawingRef.current) return;
      const p = point(e);
      const ctx = canvasRef.current!.getContext('2d')!;
      ctx.beginPath();
      ctx.moveTo(lastRef.current!.x, lastRef.current!.y);
      ctx.lineTo(p.x, p.y);
      ctx.stroke();
      lastRef.current = p;
      dirtyRef.current = true;
    };

    const up = (e: React.PointerEvent) => {
      drawingRef.current = false;
      lastRef.current = null;
      try { canvasRef.current?.releasePointerCapture(e.pointerId); } catch {}
    };

    return (
      <canvas
        ref={canvasRef}
        onPointerDown={down}
        onPointerMove={move}
        onPointerUp={up}
        onPointerCancel={up}
        className={className}
        style={{ touchAction: 'none' }}
      />
    );
  },
);

export default SignaturePad;
