'use client';
import { useEffect } from 'react';

type Props = {
  open: boolean;
  nearestCityName?: string | null;
  onClose: () => void;
};

export default function OutOfServiceArea({ open, nearestCityName, onClose }: Props) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [open, onClose]);

  if (!open) return null;

  const body = nearestCityName
    ? `Parsalo is currently live in ${nearestCityName} only. We'll be expanding to your area very soon — thanks for your patience!`
    : "Parsalo is currently live in Thrissur. We'll be in your area very soon — thanks for your patience!";

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 px-0 sm:px-4">
      <div
        className="w-full sm:max-w-sm bg-white rounded-t-3xl sm:rounded-2xl p-6 pb-8 shadow-xl"
        role="dialog"
        aria-modal="true"
      >
        <div className="mx-auto h-1 w-10 rounded-full bg-slate-200 mb-5 sm:hidden" />

        <div className="flex flex-col items-center text-center">
          <div className="h-24 w-24 rounded-full bg-brand/10 flex items-center justify-center mb-4">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="currentColor"
              className="h-12 w-12 text-brand"
            >
              <path d="M12 2C8.13 2 5 5.13 5 9c0 4.17 4.42 9.92 6.24 12.11.4.48 1.13.48 1.53 0C14.58 18.92 19 13.17 19 9c0-3.87-3.13-7-7-7zm0 2c2.76 0 5 2.24 5 5 0 2.86-3.05 7.21-5 9.88C10.05 16.21 7 11.86 7 9c0-2.76 2.24-5 5-5z" />
              <path d="M3.71 4.29 2.29 5.71l16 16 1.42-1.42z" />
            </svg>
          </div>
          <h2 className="text-lg font-bold text-slate-900 mb-2">
            We're Expanding, But Not Here Yet!
          </h2>
          <p className="text-sm text-slate-600 leading-relaxed">{body}</p>
        </div>

        <button
          type="button"
          onClick={onClose}
          className="mt-6 w-full bg-brand text-white font-semibold rounded-xl py-3 text-sm hover:opacity-90"
        >
          Pick a different location
        </button>
      </div>
    </div>
  );
}
