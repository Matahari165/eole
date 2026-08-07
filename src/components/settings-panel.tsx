"use client";

import { Check, LogOut, Music2, Save, UserRound, Volume2, Waves } from "lucide-react";
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
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [saved, setSaved] = useState(false);
  const [pending, setPending] = useState(false);
  const previewRef = useRef<AudioEngine | null>(null);

  useEffect(() => {
    Promise.all([getSoundSettings(), getProfile()]).then(([nextSettings, nextProfile]) => { setSettings(nextSettings); setProfile(nextProfile); });
    return () => previewRef.current?.destroy();
  }, []);

  async function preview() {
    previewRef.current?.destroy();
    previewRef.current = new AudioEngine(settings);
    await previewRef.current.unlock();
    previewRef.current.startAmbient();
    previewRef.current.playBreath("inhale", 2200);
    window.setTimeout(() => previewRef.current?.playBreath("exhale", 2200), 2300);
    window.setTimeout(() => previewRef.current?.stopAmbient(), 4800);
  }

  async function save() {
    setPending(true);
    await saveSoundSettings(settings);
    setPending(false);
    setSaved(true);
    window.setTimeout(() => setSaved(false), 1800);
  }

  async function signOut() {
    await createClient()?.auth.signOut();
    router.push("/connexion");
    router.refresh();
  }

  return (
    <div className="page-stack settings-page">
      <header className="page-header"><div><p className="eyebrow">Réglages</p><h1>Ton espace, ton ambiance.</h1><p>Ajuste le son sans interrompre la simplicité de la pratique.</p></div></header>
      <div className="settings-layout">
        <section className="content-card settings-section">
          <div className="settings-title"><span><Music2 size={21} /></span><div><h2>Ambiance musicale</h2><p>Choisis la texture de fond de tes séances.</p></div></div>
          <div className="track-grid">{tracks.map((track) => <label className="track-option" data-selected={settings.musicTrack === track.value} key={track.value}><input type="radio" name="track" checked={settings.musicTrack === track.value} onChange={() => setSettings({ ...settings, musicTrack: track.value })} /><span className="track-visual" aria-hidden="true"><i /><i /><i /></span><strong>{track.label}</strong><small>{track.description}</small>{settings.musicTrack === track.value && <Check className="track-check" size={17} />}</label>)}</div>
          <RangeSetting icon={<Music2 size={19} />} label="Volume de la musique" value={settings.musicVolume} onChange={(musicVolume) => setSettings({ ...settings, musicVolume })} />
          <RangeSetting icon={<Waves size={19} />} label="Volume de la respiration" value={settings.breathVolume} onChange={(breathVolume) => setSettings({ ...settings, breathVolume })} />
          <button className="button button-secondary" type="button" onClick={preview}><Volume2 size={17} /> Écouter un aperçu</button>
        </section>

        <div className="settings-side">
          <section className="content-card settings-section compact-section"><div className="settings-title"><span><Waves size={21} /></span><div><h2>Vibrations</h2><p>Désactivées par défaut.</p></div></div><label className="toggle-row"><span>Signaler les changements de phase</span><input type="checkbox" checked={settings.hapticsEnabled} onChange={(event) => setSettings({ ...settings, hapticsEnabled: event.target.checked })} /><i aria-hidden="true" /></label></section>
          <section className="content-card settings-section compact-section"><div className="settings-title"><span><UserRound size={21} /></span><div><h2>Compte</h2><p>{profile ? `${profile.firstName} · @${profile.username}` : "Chargement…"}</p></div></div><button className="text-button danger-text" type="button" onClick={signOut}><LogOut size={17} /> Se déconnecter</button></section>
        </div>
      </div>
      <div className="settings-save"><button className="button button-primary" type="button" disabled={pending} onClick={save}>{saved ? <Check size={18} /> : <Save size={18} />}{saved ? "Enregistré" : pending ? "Enregistrement…" : "Enregistrer les réglages"}</button></div>
    </div>
  );
}

function RangeSetting({ icon, label, value, onChange }: { icon: React.ReactNode; label: string; value: number; onChange: (value: number) => void }) {
  return <label className="range-setting"><span>{icon}<strong>{label}</strong></span><div><input type="range" min="0" max="100" value={value} onChange={(event) => onChange(Number(event.target.value))} aria-label={label} /><output>{value}%</output></div></label>;
}
