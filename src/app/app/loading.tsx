import { EoleMark } from "@/components/layout/brand";

export default function AppLoading() {
  return (
    <div className="page-loading" aria-busy="true" aria-label="Chargement de la page">
      <span className="page-loading-stage" aria-hidden="true">
        <i /><i /><i />
        <EoleMark size={64} className="page-loading-mark" />
      </span>
      <div>
        <p className="eyebrow">Eole</p>
        <p>Ton espace se met en place.</p>
      </div>
    </div>
  );
}
