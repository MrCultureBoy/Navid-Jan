(() => {
  'use strict';

  const STORAGE_KEY = 'voice-ideas.items.v1';
  const LANG_KEY = 'voice-ideas.lang.v1';

  const micBtn = document.getElementById('mic-btn');
  const micStatus = document.getElementById('mic-status');
  const liveTranscript = document.getElementById('live-transcript');
  const unsupportedMsg = document.getElementById('unsupported-msg');
  const langSelect = document.getElementById('lang-select');
  const manualForm = document.getElementById('manual-form');
  const manualInput = document.getElementById('manual-input');
  const searchInput = document.getElementById('search-input');
  const countBadge = document.getElementById('count-badge');
  const ideaList = document.getElementById('idea-list');
  const emptyState = document.getElementById('empty-state');
  const toast = document.getElementById('toast');
  const menuBtn = document.getElementById('menu-btn');
  const menu = document.getElementById('menu');
  const exportBtn = document.getElementById('export-btn');
  const exportTxtBtn = document.getElementById('export-txt-btn');
  const clearBtn = document.getElementById('clear-btn');

  let ideas = loadIdeas();
  let query = '';

  function loadIdeas() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : [];
    } catch {
      return [];
    }
  }

  function saveIdeas() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(ideas));
  }

  function showToast(msg) {
    toast.textContent = msg;
    toast.classList.add('show');
    clearTimeout(showToast._t);
    showToast._t = setTimeout(() => toast.classList.remove('show'), 1800);
  }

  function addIdea(text) {
    const trimmed = text.trim();
    if (!trimmed) return;
    ideas.unshift({ id: crypto.randomUUID(), text: trimmed, createdAt: Date.now() });
    saveIdeas();
    render();
    showToast('Idée enregistrée ✓');
  }

  function deleteIdea(id) {
    ideas = ideas.filter((i) => i.id !== id);
    saveIdeas();
    render();
  }

  function updateIdea(id, text) {
    const idea = ideas.find((i) => i.id === id);
    if (!idea) return;
    const trimmed = text.trim();
    if (!trimmed) {
      deleteIdea(id);
      return;
    }
    idea.text = trimmed;
    saveIdeas();
    render();
  }

  function formatDate(ts) {
    const d = new Date(ts);
    const diffMs = Date.now() - ts;
    const diffMin = Math.round(diffMs / 60000);
    if (diffMin < 1) return "à l'instant";
    if (diffMin < 60) return `il y a ${diffMin} min`;
    const diffH = Math.round(diffMin / 60);
    if (diffH < 24) return `il y a ${diffH} h`;
    return d.toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
  }

  function render() {
    const filtered = query
      ? ideas.filter((i) => i.text.toLowerCase().includes(query.toLowerCase()))
      : ideas;

    countBadge.textContent = String(ideas.length);
    emptyState.classList.toggle('hidden', ideas.length !== 0);
    ideaList.innerHTML = '';

    for (const idea of filtered) {
      const li = document.createElement('li');
      li.className = 'idea-item';

      const p = document.createElement('p');
      p.className = 'idea-text';
      p.textContent = idea.text;

      const meta = document.createElement('div');
      meta.className = 'idea-meta';

      const date = document.createElement('span');
      date.className = 'idea-date';
      date.textContent = formatDate(idea.createdAt);

      const actions = document.createElement('div');
      actions.className = 'idea-actions';

      const editBtn = document.createElement('button');
      editBtn.textContent = '✏️';
      editBtn.setAttribute('aria-label', 'Modifier');
      editBtn.addEventListener('click', () => startEdit(p, idea));

      const delBtn = document.createElement('button');
      delBtn.textContent = '🗑️';
      delBtn.setAttribute('aria-label', 'Supprimer');
      delBtn.addEventListener('click', () => deleteIdea(idea.id));

      actions.append(editBtn, delBtn);
      meta.append(date, actions);
      li.append(p, meta);
      ideaList.append(li);
    }
  }

  function startEdit(p, idea) {
    p.contentEditable = 'true';
    p.focus();
    const range = document.createRange();
    range.selectNodeContents(p);
    range.collapse(false);
    const sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);

    const finish = () => {
      p.contentEditable = 'false';
      updateIdea(idea.id, p.textContent);
      p.removeEventListener('blur', finish);
      p.removeEventListener('keydown', onKey);
    };
    const onKey = (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        p.blur();
      }
    };
    p.addEventListener('blur', finish);
    p.addEventListener('keydown', onKey);
  }

  manualForm.addEventListener('submit', (e) => {
    e.preventDefault();
    addIdea(manualInput.value);
    manualInput.value = '';
  });

  searchInput.addEventListener('input', () => {
    query = searchInput.value;
    render();
  });

  menuBtn.addEventListener('click', () => {
    const isHidden = menu.classList.toggle('hidden');
    menuBtn.setAttribute('aria-expanded', String(!isHidden));
  });

  document.addEventListener('click', (e) => {
    if (!menu.contains(e.target) && e.target !== menuBtn && !menu.classList.contains('hidden')) {
      menu.classList.add('hidden');
      menuBtn.setAttribute('aria-expanded', 'false');
    }
  });

  function download(filename, content, mime) {
    const blob = new Blob([content], { type: mime });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  }

  exportBtn.addEventListener('click', () => {
    download('mes-idees.json', JSON.stringify(ideas, null, 2), 'application/json');
    menu.classList.add('hidden');
  });

  exportTxtBtn.addEventListener('click', () => {
    const text = ideas
      .map((i) => `[${new Date(i.createdAt).toLocaleString('fr-FR')}] ${i.text}`)
      .join('\n\n');
    download('mes-idees.txt', text, 'text/plain');
    menu.classList.add('hidden');
  });

  clearBtn.addEventListener('click', () => {
    menu.classList.add('hidden');
    if (ideas.length === 0) return;
    if (confirm('Supprimer définitivement toutes vos idées ?')) {
      ideas = [];
      saveIdeas();
      render();
    }
  });

  // --- Speech recognition ---
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  let recognition = null;
  let listening = false;
  let stoppedByUser = false;

  const savedLang = localStorage.getItem(LANG_KEY);
  if (savedLang) langSelect.value = savedLang;

  langSelect.addEventListener('change', () => {
    localStorage.setItem(LANG_KEY, langSelect.value);
    if (recognition) recognition.lang = langSelect.value;
  });

  if (!SpeechRecognition) {
    unsupportedMsg.classList.remove('hidden');
    micBtn.disabled = true;
    micBtn.style.opacity = '0.5';
    micBtn.style.cursor = 'not-allowed';
  } else {
    recognition = new SpeechRecognition();
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.lang = langSelect.value;

    recognition.onresult = (event) => {
      let interim = '';
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const result = event.results[i];
        const transcript = result[0].transcript;
        if (result.isFinal) {
          addIdea(transcript);
        } else {
          interim += transcript;
        }
      }
      liveTranscript.textContent = interim;
    };

    recognition.onerror = (event) => {
      if (event.error === 'no-speech' || event.error === 'aborted') return;
      if (event.error === 'not-allowed' || event.error === 'service-not-allowed') {
        showToast("Accès au micro refusé.");
        stopListening();
        return;
      }
      showToast('Erreur de reconnaissance vocale.');
    };

    recognition.onend = () => {
      if (listening && !stoppedByUser) {
        try {
          recognition.start();
        } catch {
          listening = false;
          updateMicUI();
        }
      } else {
        listening = false;
        updateMicUI();
      }
    };

    micBtn.addEventListener('click', () => {
      if (listening) {
        stopListening();
      } else {
        startListening();
      }
    });
  }

  function startListening() {
    stoppedByUser = false;
    try {
      recognition.start();
      listening = true;
      updateMicUI();
    } catch {
      // already started
    }
  }

  function stopListening() {
    stoppedByUser = true;
    listening = false;
    liveTranscript.textContent = '';
    try {
      recognition.stop();
    } catch {
      // ignore
    }
    updateMicUI();
  }

  function updateMicUI() {
    micBtn.classList.toggle('listening', listening);
    micBtn.setAttribute('aria-pressed', String(listening));
    micBtn.setAttribute('aria-label', listening ? 'Arrêter la capture vocale' : 'Démarrer la capture vocale');
    micStatus.textContent = listening
      ? 'Je vous écoute… parlez, une pause = une idée enregistrée'
      : 'Appuyez pour parler';
    if (!listening) liveTranscript.textContent = '';
  }

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('sw.js').catch(() => {});
    });
  }

  render();
})();
