export default function AppLoading() {
  return (
    <div className="page-loading" aria-busy="true" aria-label="Chargement de la page">
      <span className="page-loading-stage" aria-hidden="true">
        <i /><i /><i />
        <span className="page-loading-orb" />
      </span>
      <div>
        <p className="eyebrow">Eole</p>
        <p>Ton espace se met en place.</p>
      </div>
    </div>
  );
}
