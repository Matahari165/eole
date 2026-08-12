"use client";

import { Check, LoaderCircle, Music2, Save, Volume2, VolumeX, Waves } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { AudioEngine } from "@/lib/audio-engine";
import { getSoundSettings, saveSoundSettings } from "@/lib/repository";
import { DEFAULT_SOUND_SETTINGS, type SoundSettings } from "@/lib/types";

const tracks: { value: SoundSettings["musicTrack"]; label: string; description: string }[] = [
  { value: "pluie", label: "Pluie douce", description: "Bruit blanc naturel" },
  { value: "ocean", label: "Vagues de l'océan", description: "Flux et reflux apaisant" },
  { value: "foret", label: "Forêt paisible", description: "Ambiance zen" },
];

export function SettingsPanel() {
  const [settings, setSettings] = useState(DEFAULT_SOUND_SETTINGS);
  const [initialSettings, setInitialSettings] = useState(DEFAULT_SOUND_SETTINGS);
  const [saved, setSaved] = useState(false);
  const [pending, setPending] = useState(false);
  const [ready, setReady] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);
  const [previewing, setPreviewing] = useState(false);
  const [previewPending, setPreviewPending] = useState(false);
  const [supportsHaptics, setSupportsHaptics] = useState(false);
  const previewRef = useRef<AudioEngine | null>(null);
  const previewTimersRef = useRef<number[]>([]);
  const savedTimerRef = useRef<number | null>(null);

  useEffect(() => {
    let active = true;
    getSoundSettings()
      .then((nextSettings) => {
        if (!active) return;
        setSupportsHaptics("vibrate" in navigator);
        setInitialSettings(nextSettings);
        setSettings(nextSettings);
      })
      .catch(() => active && setFeedback("Les réglages n’ont pas pu être chargés. Les valeurs par défaut restent utilisables."))
      .finally(() => active && setReady(true));
    return () => {
      active = false;
      previewTimersRef.current.forEach((timer) => window.clearTimeout(timer));
      if (savedTimerRef.current) window.clearTimeout(savedTimerRef.current);
      previewRef.current?.destroy();
    };
  }, []);

  useEffect(() => previewRef.current?.updateSettings(settings), [settings]);

  function stopPreview() {
    previewTimersRef.current.forEach((timer) => window.clearTimeout(timer));
    previewTimersRef.current = [];
    previewRef.current?.destroy();
    previewRef.current = null;
    setPreviewing(false);
  }

  async function preview() {
    if (previewPending) return;
    if (previewing) {
      stopPreview();
      return;
    }
    setPreviewPending(true);
    setFeedback(null);
    previewRef.current = new AudioEngine(settings);
    try {
      await previewRef.current.unlock();
      previewRef.current.startAmbient();
      previewRef.current.playBreath("inhale", 2200);
      setPreviewing(true);
      previewTimersRef.current = [
        window.setTimeout(() => previewRef.current?.playBreath("exhale", 2200), 2300),
        window.setTimeout(stopPreview, 4800),
      ];
    } catch {
      stopPreview();
      setFeedback("Le son n’a pas pu démarrer. Vérifie le volume de l’iPhone puis réessaie.");
    } finally {
      setPreviewPending(false);
    }
  }

  async function save() {
    setPending(true);
    setFeedback(null);
    try {
      await saveSoundSettings(settings);
      setInitialSettings(settings);
      setSaved(true);
      if (savedTimerRef.current) window.clearTimeout(savedTimerRef.current);
      savedTimerRef.current = window.setTimeout(() => setSaved(false), 1800);
    } catch {
      setFeedback("Les réglages n’ont pas été enregistrés. Vérifie ta connexion puis réessaie.");
    } finally {
      setPending(false);
    }
  }

  const dirty = ready && JSON.stringify(settings) !== JSON.stringify(initialSettings);

  if (!ready) {
    return <div className="page-stack" aria-busy="true" aria-label="Chargement des réglages"><div className="skeleton skeleton-title" /><div className="skeleton skeleton-settings" /></div>;
  }

  return (
    <div className="page-stack settings-page">
      <header className="page-header"><div><p className="eyebrow">Réglages</p><h1>Ton espace, ton ambiance.</h1></div></header>
      <div className="settings-layout">
        <section className="content-card settings-section">
          <div className="settings-title"><span><Music2 size={21} aria-hidden="true" /></span><div><h2>Ambiance musicale</h2></div></div>
          <fieldset className="track-fieldset"><legend className="sr-only">Ambiance musicale</legend><div className="track-grid">{tracks.map((track) => <label className="track-option" data-selected={settings.musicTrack === track.value} key={track.value}><input type="radio" name="track" checked={settings.musicTrack === track.value} onChange={() => setSettings({ ...settings, musicTrack: track.value })} /><span className="track-visual" aria-hidden="true"><i /><i /><i /></span><strong>{track.label}</strong><small>{track.description}</small>{settings.musicTrack === track.value && <Check className="track-check" size={17} aria-hidden="true" />}</label>)}</div></fieldset>
          <RangeSetting icon={<Music2 size={19} />} label="Volume de la musique" value={settings.musicVolume} onChange={(musicVolume) => setSettings({ ...settings, musicVolume })} />
          <RangeSetting icon={<Waves size={19} />} label="Volume de la respiration" value={settings.breathVolume} onChange={(breathVolume) => setSettings({ ...settings, breathVolume })} />
          <button className="button button-secondary" type="button" disabled={previewPending} onClick={preview}>{previewPending ? <LoaderCircle className="spin" size={17} aria-hidden="true" /> : previewing ? <VolumeX size={17} aria-hidden="true" /> : <Volume2 size={17} aria-hidden="true" />}{previewPending ? "Préparation du son…" : previewing ? "Arrêter l’aperçu" : "Écouter un aperçu"}</button>
        </section>

        <div className="settings-side">
          {supportsHaptics && <section className="content-card settings-section compact-section"><div className="settings-title"><span><Waves size={21} aria-hidden="true" /></span><div><h2>Vibrations</h2><p>Désactivées par défaut.</p></div></div><label className="toggle-row"><span>Signaler les changements de phase</span><input type="checkbox" checked={settings.hapticsEnabled} onChange={(event) => setSettings({ ...settings, hapticsEnabled: event.target.checked })} /><i aria-hidden="true" /></label></section>}
        </div>
      </div>
      {(feedback || dirty || pending || saved) && <div className="settings-actions">
        {feedback && <p className="form-error" role="alert">{feedback}</p>}
        {(dirty || pending || saved) && <button className="button button-primary" type="button" disabled={pending || !dirty} onClick={save}>
          {pending ? <LoaderCircle className="spin" size={18} aria-hidden="true" /> : saved || !dirty ? <Check size={18} aria-hidden="true" /> : <Save size={18} aria-hidden="true" />}
          {saved ? "Enregistré" : pending ? "Enregistrement…" : "Enregistrer les changements"}
        </button>}
      </div>}
    </div>
  );
}

function RangeSetting({ icon, label, value, onChange }: { icon: React.ReactNode; label: string; value: number; onChange: (value: number) => void }) {
  return <label className="range-setting"><span>{icon}<strong>{label}</strong></span><div><input type="range" min="0" max="100" value={value} onChange={(event) => onChange(Number(event.target.value))} aria-label={label} aria-valuetext={`${value} %`} /><output>{value}%</output></div></label>;
}
