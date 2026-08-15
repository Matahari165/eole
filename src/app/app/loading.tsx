export default function AppLoading() {
  return (
    <div className="page-loading" aria-busy="true" aria-label="Chargement de la page">
      <span className="page-loading-orb" aria-hidden="true" />
      <div>
        <p className="eyebrow">Eole</p>
        <p>Un instant, tout se met en place.</p>
      </div>
    </div>
  );
}
