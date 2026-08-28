"use client";

import { ArrowRight, Check, Gauge, Minus, Plus, Save, RotateCcw, Wind } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { getSessionDefaults, saveSessionDefaults } from "@/lib/session-defaults";
import { DEFAULT_SESSION_CONFIG, type Pace } from "@/lib/types";

const paceOptions: { value: Pace; label: string; detail: string }[] = [
  { value: "slow", label: "Lente", detail: "6 s / souffle" },
  { value: "normal", label: "Normale", detail: "4 s / souffle" },
  { value: "fast", label: "Rapide", detail: "2,5 s / souffle" },
];

export function SessionConfigurator() {
  const router = useRouter();
  const [rounds, setRounds] = useState(DEFAULT_SESSION_CONFIG.rounds);
  const [breaths, setBreaths] = useState(DEFAULT_SESSION_CONFIG.breathsPerRound);
  const [pace, setPace] = useState<Pace>(DEFAULT_SESSION_CONFIG.pace);
  const [savedDefaults, setSavedDefaults] = useState(DEFAULT_SESSION_CONFIG);
  const [savedNotice, setSavedNotice] = useState(false);
  const paceSummary = pace === "slow" ? "lent" : pace === "fast" ? "rapide" : "normal";
  const customized = rounds !== savedDefaults.rounds || breaths !== savedDefaults.breathsPerRound || pace !== savedDefaults.pace;

  useEffect(() => {
    let active = true;
    Promise.resolve().then(() => {
      if (!active) return;
      const defaults = getSessionDefaults();
      setSavedDefaults(defaults);
      setRounds(defaults.rounds);
      setBreaths(defaults.breathsPerRound);
      setPace(defaults.pace);
    });
    return () => { active = false; };
  }, []);

  function start() {
    const params = new URLSearchParams({
      rounds: String(rounds),
      breaths: String(breaths),
      pace,
      startedAt: new Date().toISOString(),
    });
    router.push(`/app/session/active?${params.toString()}`);
  }

  function saveAsDefault() {
    const defaults = { rounds, breathsPerRound: breaths, pace };
    saveSessionDefaults(defaults);
    setSavedDefaults(defaults);
    setSavedNotice(true);
  }

  return (
    <div className="page-stack setup-page">
      <header className="page-header">
        <div><p className="eyebrow">Nouvelle séance</p><h1>Prépare ton rythme.</h1></div>
      </header>

      <section className="setup-quick-start" aria-labelledby="quick-start-title">
        <div className="quick-start-copy">
          <h2 id="quick-start-title">Lance ta séance</h2>
          <p>{rounds} rounds · {breaths} respirations · rythme {paceSummary}</p>
        </div>
        <button className="button button-primary button-large quick-start-action" type="button" onClick={start} aria-label={`Lancer la séance : ${rounds} rounds, ${breaths} respirations, rythme ${paceSummary}`}>
          Lancer <ArrowRight size={18} aria-hidden="true" />
        </button>
      </section>

      <section className="setup-controls" aria-labelledby="setup-details-title">
        <div className="setup-details-heading">
          <div><h2 id="setup-details-title">Personnaliser la séance</h2></div>
          {customized && <button className="reset-settings" type="button" onClick={() => { setRounds(savedDefaults.rounds); setBreaths(savedDefaults.breathsPerRound); setPace(savedDefaults.pace); setSavedNotice(false); }}><RotateCcw size={16} aria-hidden="true" /> Réinitialiser</button>}
        </div>
        <div className="setup-control-grid">
          <Stepper icon={<RotateCcw size={20} />} label="Nombre de rounds" value={rounds} min={1} max={8} onChange={setRounds} />
          <Stepper icon={<Wind size={20} />} label="Respirations" value={breaths} min={10} max={60} step={5} onChange={setBreaths} />
          <fieldset className="setting-card pace-card">
            <legend className="sr-only">Vitesse</legend>
            <div className="setting-label"><span className="setting-icon" aria-hidden="true"><Gauge size={20} /></span><span><strong>Vitesse</strong></span></div>
            <div className="pace-options">
              {paceOptions.map((option) => <label className="pace-option" data-selected={pace === option.value} key={option.value}><input type="radio" name="pace" value={option.value} checked={pace === option.value} onChange={() => setPace(option.value)} /><span>{option.label}</span><small>{option.detail}</small></label>)}
            </div>
          </fieldset>
        </div>
        <div className="setup-default-actions">
          <div><strong>Réglages par défaut</strong><p>Utiliser cette configuration pour les prochaines séances.</p></div>
          <button className="button button-secondary" type="button" onClick={saveAsDefault} disabled={!customized}>
            {savedNotice && !customized ? <Check size={17} aria-hidden="true" /> : <Save size={17} aria-hidden="true" />}
            {savedNotice && !customized ? "Réglages enregistrés" : "Définir par défaut"}
          </button>
        </div>
        {savedNotice && <p className="sr-only" role="status">Ces réglages seront utilisés par défaut pour les prochaines séances.</p>}
      </section>
    </div>
  );
}

function Stepper({ icon, label, hint, value, min, max, step = 1, onChange }: { icon: React.ReactNode; label: string; hint?: string; value: number; min: number; max: number; step?: number; onChange: (value: number) => void }) {
  return (
    <div className="setting-card stepper-card">
      <div className="setting-label"><span className="setting-icon" aria-hidden="true">{icon}</span><span><strong>{label}</strong>{hint && <small>{hint}</small>}</span></div>
      <div className="stepper"><button type="button" onClick={() => onChange(Math.max(min, value - step))} disabled={value <= min} aria-label={`Diminuer ${label.toLowerCase()}`}><Minus size={19} /></button><output aria-live="polite">{value}</output><button type="button" onClick={() => onChange(Math.min(max, value + step))} disabled={value >= max} aria-label={`Augmenter ${label.toLowerCase()}`}><Plus size={19} /></button></div>
    </div>
  );
}
