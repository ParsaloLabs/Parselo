'use client';
import { useEffect, useState } from 'react';

type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
};

export default function PWA() {
  const [deferred, setDeferred] = useState<BeforeInstallPromptEvent | null>(null);
  const [dismissed, setDismissed] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js').catch(() => {});
    }
    const onPrompt = (e: Event) => {
      e.preventDefault();
      setDeferred(e as BeforeInstallPromptEvent);
    };
    window.addEventListener('beforeinstallprompt', onPrompt);
    return () => window.removeEventListener('beforeinstallprompt', onPrompt);
  }, []);

  if (!deferred || dismissed) return null;

  const install = async () => {
    await deferred.prompt();
    await deferred.userChoice;
    setDeferred(null);
  };

  return (
    <div className="fixed bottom-4 left-4 right-4 md:left-auto md:right-4 md:w-80 bg-white border border-slate-200 rounded-xl shadow-lg p-4 z-50">
      <div className="flex items-start gap-3">
        <div className="text-2xl">📦</div>
        <div className="flex-1">
          <div className="font-semibold text-sm">Install Parsalo</div>
          <div className="text-xs text-slate-500 mt-0.5">
            Add to your home screen for quicker access
          </div>
        </div>
        <button onClick={() => setDismissed(true)}
          className="text-slate-400 hover:text-slate-600 text-lg leading-none">×</button>
      </div>
      <button onClick={install}
        className="w-full mt-3 bg-brand text-white text-sm font-semibold rounded-lg py-2 hover:bg-brand-dark">
        Install
      </button>
    </div>
  );
}
