const WEBHOOK_URL = 'https://n8n-formation.isao.io/webhook/capture-lead-espace-conseil';

// Compteur de caractères pour le champ besoin
const besoinField = document.getElementById('besoin');
const charCount   = document.getElementById('charCount');

if (besoinField && charCount) {
  besoinField.addEventListener('input', () => {
    charCount.textContent = besoinField.value.length;
  });
}

// Gestion du formulaire
const form      = document.getElementById('contactForm');
const submitBtn = document.getElementById('submitBtn');
const btnText   = submitBtn?.querySelector('.btn__text');
const btnLoader = submitBtn?.querySelector('.btn__loader');
const successEl = document.getElementById('formSuccess');
const errorEl   = document.getElementById('formError');

function setLoading(loading) {
  submitBtn.disabled = loading;
  btnText.hidden     = loading;
  btnLoader.hidden   = !loading;
}

function showMessage(el, duration = 6000) {
  el.hidden = false;
  if (duration) setTimeout(() => { el.hidden = true; }, duration);
}

form?.addEventListener('submit', async (e) => {
  e.preventDefault();

  successEl.hidden = true;
  errorEl.hidden   = true;

  const data = {
    nom:        form.nom.value.trim(),
    prenom:     form.prenom.value.trim(),
    email:      form.email.value.trim(),
    telephone:  form.telephone.value.trim(),
    entreprise: form.entreprise.value.trim(),
    besoin:     form.besoin.value.trim(),
    rgpd:       form.rgpd.checked,
    source:     'landing-page-espace-conseil',
    date:       new Date().toISOString(),
  };

  setLoading(true);

  try {
    const res = await fetch(WEBHOOK_URL, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify(data),
    });

    if (!res.ok) throw new Error(`HTTP ${res.status}`);

    form.reset();
    charCount.textContent = '0';
    showMessage(successEl);
  } catch (err) {
    console.error('Erreur webhook:', err);
    showMessage(errorEl);
  } finally {
    setLoading(false);
  }
});
