"use client";

import { Check, LoaderCircle, LogOut, Music2, Save, UserRound, Volume2, VolumeX, Waves } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { AudioEngine } from "@/lib/audio-engine";
import { getProfile, getSoundSettings, saveSoundSettings } from "@/lib/repository";
import { createClient } from "@/lib/supabase/client";
import { DEFAULT_SOUND_SETTINGS, type SoundSettings, type UserProfile } from "@/lib/types";

const tracks: { value: SoundSettings["musicTrack"]; label: string; description: string }[] = [
  { value: "glacier", label: "Glacier", description: "Claire et profonde" },
  { value: "lagon", label: "Lagon", description: "Douce et enveloppante" },
  { value: "aurore", label: "Aurore", description: "Légère et lumineuse" },
];

export function SettingsPanel() {
  const router = useRouter();
  const [settings, setSettings] = useState(DEFAULT_SOUND_SETTINGS);
  const [initialSettings, setInitialSettings] = useState(DEFAULT_SOUND_SETTINGS);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [saved, setSaved] = useState(false);
  const [pending, setPending] = useState(false);
  const [ready, setReady] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);
  const [previewing, setPreviewing] = useState(false);
  const [previewPending, setPreviewPending] = useState(false);
  const [signingOut, setSigningOut] = useState(false);
  const [supportsHaptics, setSupportsHaptics] = useState(false);
  const previewRef = useRef<AudioEngine | null>(null);
  const previewTimersRef = useRef<number[]>([]);
  const savedTimerRef = useRef<number | null>(null);

  useEffect(() => {
    let active = true;
    Promise.allSettled([getSoundSettings(), getProfile()])
      .then(([settingsResult, profileResult]) => {
        if (!active) return;
        setSupportsHaptics("vibrate" in navigator);
        if (settingsResult.status === "fulfilled") {
          setInitialSettings(settingsResult.value);
          setSettings(settingsResult.value);
        }
        if (profileResult.status === "fulfilled") setProfile(profileResult.value);
        if (settingsResult.status === "rejected" || profileResult.status === "rejected") {
          setFeedback("Certains réglages n’ont pas pu être chargés. Les valeurs disponibles restent utilisables.");
        }
      })
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

  async function signOut() {
    if (signingOut) return;
    setSigningOut(true);
    setFeedback(null);
    try {
      await createClient()?.auth.signOut();
      router.replace("/connexion");
      router.refresh();
    } catch {
      setFeedback("La déconnexion a échoué. Réessaie dans un instant.");
      setSigningOut(false);
    }
  }

  const dirty = ready && JSON.stringify(settings) !== JSON.stringify(initialSettings);

  if (!ready) {
    return <div className="page-stack" aria-busy="true" aria-label="Chargement des réglages"><div className="skeleton skeleton-title" /><div className="skeleton skeleton-settings" /></div>;
  }

  return (
    <div className="page-stack settings-page">
      <header className="page-header"><div><p className="eyebrow">Réglages</p><h1>Ton espace, ton ambiance.</h1><p>Ajuste le son sans interrompre la simplicité de la pratique.</p></div></header>
      <div className="settings-layout">
        <section className="content-card settings-section">
          <div className="settings-title"><span><Music2 size={21} /></span><div><h2>Ambiance musicale</h2><p>Choisis la texture de fond de tes séances.</p></div></div>
          <fieldset className="track-fieldset"><legend className="sr-only">Ambiance musicale</legend><div className="track-grid">{tracks.map((track) => <label className="track-option" data-selected={settings.musicTrack === track.value} key={track.value}><input type="radio" name="track" checked={settings.musicTrack === track.value} onChange={() => setSettings({ ...settings, musicTrack: track.value })} /><span className="track-visual" aria-hidden="true"><i /><i /><i /></span><strong>{track.label}</strong><small>{track.description}</small>{settings.musicTrack === track.value && <Check className="track-check" size={17} aria-hidden="true" />}</label>)}</div></fieldset>
          <RangeSetting icon={<Music2 size={19} />} label="Volume de la musique" value={settings.musicVolume} onChange={(musicVolume) => setSettings({ ...settings, musicVolume })} />
          <RangeSetting icon={<Waves size={19} />} label="Volume de la respiration" value={settings.breathVolume} onChange={(breathVolume) => setSettings({ ...settings, breathVolume })} />
          <button className="button button-secondary" type="button" disabled={previewPending} onClick={preview}>{previewPending ? <LoaderCircle className="spin" size={17} aria-hidden="true" /> : previewing ? <VolumeX size={17} aria-hidden="true" /> : <Volume2 size={17} aria-hidden="true" />}{previewPending ? "Préparation du son…" : previewing ? "Arrêter l’aperçu" : "Écouter un aperçu"}</button>
        </section>

        <div className="settings-side">
          {supportsHaptics && <section className="content-card settings-section compact-section"><div className="settings-title"><span><Waves size={21} aria-hidden="true" /></span><div><h2>Vibrations</h2><p>Désactivées par défaut.</p></div></div><label className="toggle-row"><span>Signaler les changements de phase</span><input type="checkbox" checked={settings.hapticsEnabled} onChange={(event) => setSettings({ ...settings, hapticsEnabled: event.target.checked })} /><i aria-hidden="true" /></label></section>}
          <section className="content-card settings-section compact-section"><div className="settings-title"><span><UserRound size={21} aria-hidden="true" /></span><div><h2>Compte</h2><p>{profile ? `${profile.firstName} · @${profile.username}` : "Profil indisponible"}</p></div></div><button className="text-button danger-text" type="button" disabled={signingOut} onClick={signOut}>{signingOut ? <LoaderCircle className="spin" size={17} aria-hidden="true" /> : <LogOut size={17} aria-hidden="true" />}{signingOut ? "Déconnexion…" : "Se déconnecter"}</button></section>
        </div>
      </div>
      <div className="settings-actions">
        {feedback && <p className="form-error" role="alert">{feedback}</p>}
        <button className="button button-primary" type="button" disabled={pending || !dirty} onClick={save}>
          {pending ? <LoaderCircle className="spin" size={18} aria-hidden="true" /> : saved || !dirty ? <Check size={18} aria-hidden="true" /> : <Save size={18} aria-hidden="true" />}
          {saved ? "Enregistré" : pending ? "Enregistrement…" : dirty ? "Enregistrer les réglages" : "Réglages à jour"}
        </button>
      </div>
    </div>
  );
}

function RangeSetting({ icon, label, value, onChange }: { icon: React.ReactNode; label: string; value: number; onChange: (value: number) => void }) {
  return <label className="range-setting"><span>{icon}<strong>{label}</strong></span><div><input type="range" min="0" max="100" value={value} onChange={(event) => onChange(Number(event.target.value))} aria-label={label} aria-valuetext={`${value} %`} /><output>{value}%</output></div></label>;
}
