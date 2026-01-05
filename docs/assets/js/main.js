// Main JS
document.addEventListener('DOMContentLoaded', function() {
  // Sidebar Logic
  const menuToggle = document.getElementById('menu-toggle');
  const sidebar = document.querySelector('.sidebar');

  if (menuToggle && sidebar) {
    // Create overlay
    const overlay = document.createElement('div');
    overlay.className = 'sidebar-overlay';
    document.body.appendChild(overlay);

    menuToggle.addEventListener('click', function() {
      sidebar.classList.toggle('open');
      overlay.classList.toggle('active');
    });

    overlay.addEventListener('click', function() {
      sidebar.classList.remove('open');
      overlay.classList.remove('active');
    });
  }

  // Theme Settings Logic (Dialog & Palettes)
  initThemeSettings();

  // Auto-expand Sidebar
  const activeLink = document.querySelector('.nav-link.active');
  if (activeLink) {
    let parent = activeLink.closest('details');
    while (parent) {
      parent.setAttribute('open', '');
      parent = parent.parentElement.closest('details');
    }
  }

  console.log('Materialistic Jekyll Theme Loaded');
});
// Material Components Logic
function initMaterialComponents() {

  // Ripple Effect
  function createRipple(event) {
    const element = event.currentTarget;

    // Create ripple element
    const circle = document.createElement('span');
    const diameter = Math.max(element.clientWidth, element.clientHeight);
    const radius = diameter / 2;

    const rect = element.getBoundingClientRect();

    circle.style.width = circle.style.height = `${diameter}px`;
    circle.style.left = `${event.clientX - rect.left - radius}px`;
    circle.style.top = `${event.clientY - rect.top - radius}px`;
    circle.classList.add('ripple');

    // Remove existing ripples to avoid clutter (optional, but cleaner)
    // Actually, allowing multiple ripples is more Material-like

    element.appendChild(circle);

    setTimeout(() => {
      circle.remove();
    }, 600);
  }

  // Attach ripple to interactive elements
  const rippleElements = document.querySelectorAll(
    '.btn, .fab, .icon-btn, .segmented-btn, .chip, .tab-item, .nav-rail-item, .list-item'
  );

  rippleElements.forEach(el => {
    el.addEventListener('mousedown', createRipple);
  });

  // Tabs Logic
  const tabs = document.querySelectorAll('.tab-item');
  tabs.forEach(tab => {
    tab.addEventListener('click', function() {
      // Find parent container to scope the change
      const container = this.closest('.tabs');
      if (container) {
        container.querySelectorAll('.tab-item').forEach(t => t.classList.remove('active'));
        this.classList.add('active');
      }
    });
  });

  // Segmented Button Logic
  const segButtons = document.querySelectorAll('.segmented-btn');
  segButtons.forEach(btn => {
    btn.addEventListener('click', function() {
      const container = this.closest('.segmented-btn-group');
      if (container) {
        // Assume single select for now as it's the most common and matches tabs
        container.querySelectorAll('.segmented-btn').forEach(b => b.classList.remove('selected'));
        this.classList.add('selected');
      }
    });
  });

  // Navigation Rail Logic
  const navItems = document.querySelectorAll('.nav-rail-item');
  navItems.forEach(item => {
    item.addEventListener('click', function() {
      const container = this.closest('.nav-rail');
      if (container) {
        container.querySelectorAll('.nav-rail-item').forEach(i => i.classList.remove('active'));
        this.classList.add('active');
      }
    });
  });

  // Chips Logic (Filter chips toggle)
  const chips = document.querySelectorAll('.chip.filled');
  chips.forEach(chip => {
    chip.addEventListener('click', function() {
       // Toggle visual state for demo purposes
       // We'll toggle between filled and tonal (secondary-container vs surface-variant? No, just keep filled or remove it)
       // Let's just toggle a 'selected' class if we had one, but 'filled' is the style.
       // We can toggle 'filled' class off/on.
       this.classList.toggle('filled');
       // If it becomes unfilled, maybe it should be outlined?
       // If we remove .filled, it defaults to outlined style (transparent bg, border).
    });
  });

  // Snackbar Demo Logic
  const snackbarActions = document.querySelectorAll('.snackbar-action');
  snackbarActions.forEach(action => {
    action.addEventListener('click', function() {
      const snackbar = this.closest('.snackbar');
      if (snackbar) {
        snackbar.style.opacity = '0';
        setTimeout(() => snackbar.style.display = 'none', 200);
      }
    });
  });

  // Dialog Demo Logic
  const dialogActions = document.querySelectorAll('.dialog-actions button');
  dialogActions.forEach(btn => {
    btn.addEventListener('click', function() {
      const dialog = this.closest('.dialog');
      if (dialog) {
        // Fade out
        dialog.style.opacity = '0';
        dialog.style.transition = 'opacity 0.2s';
        setTimeout(() => dialog.style.display = 'none', 200);
      }
    });
  });
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', initMaterialComponents);

function initThemeSettings() {
  const settingsBtn = document.getElementById('theme-settings-btn');
  const dialog = document.getElementById('theme-dialog');
  const backdrop = document.getElementById('theme-backdrop');
  const closeBtn = document.getElementById('close-theme-dialog');
  const html = document.documentElement;

  // Dialog Open/Close
  function openDialog() {
    if (dialog && backdrop) {
      dialog.style.display = 'block';
      backdrop.style.display = 'block';
      // Force reflow
      void dialog.offsetWidth;
      dialog.style.opacity = '1';
      backdrop.style.opacity = '1';
    }
  }

  function closeDialog() {
    if (dialog && backdrop) {
      dialog.style.opacity = '0';
      backdrop.style.opacity = '0';
      setTimeout(() => {
        dialog.style.display = 'none';
        backdrop.style.display = 'none';
      }, 200);
    }
  }

  if (settingsBtn) settingsBtn.addEventListener('click', openDialog);
  if (closeBtn) closeBtn.addEventListener('click', closeDialog);
  if (backdrop) backdrop.addEventListener('click', closeDialog);

  // Dark Mode
  const darkModeSwitch = document.getElementById('dark-mode-switch');
  const storedDarkMode = localStorage.getItem('theme-dark-mode');

  function setDarkMode(isDark) {
    if (isDark) {
      html.classList.add('dark');
    } else {
      html.classList.remove('dark');
    }
    if (darkModeSwitch) darkModeSwitch.checked = isDark;
    localStorage.setItem('theme-dark-mode', isDark);
  }

  // Init Dark Mode
  if (storedDarkMode === 'true' || (!storedDarkMode && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
    setDarkMode(true);
  } else {
    setDarkMode(false);
  }

  if (darkModeSwitch) {
    darkModeSwitch.addEventListener('change', function() {
      setDarkMode(this.checked);
    });
  }

  // Palette Picker
  const swatches = document.querySelectorAll('.palette-swatch');
  const storedPalette = localStorage.getItem('theme-palette');

  function setPalette(paletteId) {
    // Remove existing palette classes
    const classes = html.className.split(' ').filter(c => !c.startsWith('palette-'));
    html.className = classes.join(' ') + ' ' + paletteId;

    // Update selection UI
    swatches.forEach(s => {
      if (s.dataset.paletteId === paletteId) {
        s.classList.add('selected');
      } else {
        s.classList.remove('selected');
      }
    });

    localStorage.setItem('theme-palette', paletteId);
  }

  // Init Palette
  let currentPalette = storedPalette;
  if (!currentPalette) {
    // Fallback to server-side default or first palette
    const currentClass = html.className.split(' ').find(c => c.startsWith('palette-'));
    currentPalette = currentClass || 'palette-25'; // Default Deep Blue
  }
  setPalette(currentPalette);

  swatches.forEach(swatch => {
    swatch.addEventListener('click', function() {
      setPalette(this.dataset.paletteId);
    });
  });
}
