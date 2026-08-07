"use client";

import { ArrowRight, Gauge, Minus, Plus, RotateCcw, Wind } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";
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

  function start() {
    const params = new URLSearchParams({ rounds: String(rounds), breaths: String(breaths), pace });
    router.push(`/app/session/active?${params.toString()}`);
  }

  return (
    <div className="page-stack setup-page">
      <header className="page-header">
        <div><p className="eyebrow">Nouvelle séance</p><h1>Prépare ton rythme.</h1><p>Ajuste seulement ce dont tu as besoin aujourd’hui.</p></div>
        <button className="button button-ghost" type="button" onClick={() => { setRounds(3); setBreaths(35); setPace("normal"); }}><RotateCcw size={17} aria-hidden="true" /> Valeurs par défaut</button>
      </header>

      <div className="setup-layout">
        <section className="setup-controls">
          <Stepper icon={<RotateCcw size={20} />} label="Nombre de rounds" hint="Cycles complets" value={rounds} min={1} max={8} onChange={setRounds} />
          <Stepper icon={<Wind size={20} />} label="Respirations" hint="Avant chaque rétention" value={breaths} min={10} max={60} step={5} onChange={setBreaths} />
          <fieldset className="setting-card pace-card">
            <legend><span className="setting-icon"><Gauge size={20} aria-hidden="true" /></span><span><strong>Vitesse</strong><small>Rythme inspiration / expiration</small></span></legend>
            <div className="pace-options">
              {paceOptions.map((option) => <label className="pace-option" data-selected={pace === option.value} key={option.value}><input type="radio" name="pace" value={option.value} checked={pace === option.value} onChange={() => setPace(option.value)} /><span>{option.label}</span><small>{option.detail}</small></label>)}
            </div>
          </fieldset>
        </section>

        <aside className="session-preview">
          <div className="preview-orb" aria-hidden="true"><span /></div>
          <p className="eyebrow">Ta séance</p>
          <h2>{rounds} round{rounds > 1 ? "s" : ""}</h2>
          <div className="preview-details"><span>{breaths} respirations</span><span>Rétention libre</span><span>Récupération 15 s</span></div>
          <button className="button button-primary button-wide" type="button" onClick={start}>Continuer <ArrowRight size={18} aria-hidden="true" /></button>
          <p className="preview-note">Sur l’écran suivant, touche « Commencer » quand tu es installé. Aucun compte à rebours.</p>
        </aside>
      </div>
    </div>
  );
}

function Stepper({ icon, label, hint, value, min, max, step = 1, onChange }: { icon: React.ReactNode; label: string; hint: string; value: number; min: number; max: number; step?: number; onChange: (value: number) => void }) {
  return (
    <div className="setting-card stepper-card">
      <div className="setting-label"><span className="setting-icon" aria-hidden="true">{icon}</span><span><strong>{label}</strong><small>{hint}</small></span></div>
      <div className="stepper"><button type="button" onClick={() => onChange(Math.max(min, value - step))} disabled={value <= min} aria-label={`Diminuer ${label.toLowerCase()}`}><Minus size={19} /></button><output aria-live="polite">{value}</output><button type="button" onClick={() => onChange(Math.min(max, value + step))} disabled={value >= max} aria-label={`Augmenter ${label.toLowerCase()}`}><Plus size={19} /></button></div>
    </div>
  );
}
