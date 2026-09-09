/**
 * RBX Rewards - Interactive Portal Scripts
 * Dark/Light Mode, TOC Scrollspy, Search Filter, Accordions, Data Deletion
 */

document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  initReadingProgress();
  initMobileDrawer();
  initTOCScrollSpy();
  initFaqAccordion();
  initHubSearch();
  initDataDeletionForm();
  initShareAndPrint();
});

/* --- 1. Theme Management (Dark / Light) --- */
function initTheme() {
  const themeToggleButtons = document.querySelectorAll('.theme-toggle-btn');
  const storedTheme = localStorage.getItem('rbx_portal_theme') || 'light';
  
  setTheme(storedTheme);

  themeToggleButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const currentTheme = document.documentElement.getAttribute('data-theme') || 'light';
      const nextTheme = currentTheme === 'light' ? 'dark' : 'light';
      setTheme(nextTheme);
    });
  });
}

function setTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  localStorage.setItem('rbx_portal_theme', theme);
  
  // Update toggle button icons (Moon for dark, Sun for light)
  document.querySelectorAll('.theme-toggle-btn').forEach(btn => {
    btn.innerHTML = theme === 'dark' 
      ? '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg>'
      : '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/></svg>';
    btn.setAttribute('aria-label', `Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`);
  });
}

/* --- 2. Reading Progress Bar --- */
function initReadingProgress() {
  const progressBar = document.querySelector('.reading-progress-bar');
  if (!progressBar) return;

  window.addEventListener('scroll', () => {
    const totalHeight = document.documentElement.scrollHeight - window.innerHeight;
    if (totalHeight <= 0) return;
    const progress = (window.scrollY / totalHeight) * 100;
    progressBar.style.width = `${Math.min(100, Math.max(0, progress))}%`;
  }, { passive: true });
}

/* --- 3. Mobile Navigation Drawer --- */
function initMobileDrawer() {
  const mobileToggle = document.querySelector('.mobile-toggle-btn');
  const drawer = document.querySelector('.mobile-drawer');
  const overlay = document.querySelector('.mobile-drawer-overlay');
  const closeBtn = document.querySelector('.mobile-drawer-close');

  if (!mobileToggle || !drawer || !overlay) return;

  const openDrawer = () => {
    drawer.classList.add('open');
    overlay.classList.add('open');
    document.body.style.overflow = 'hidden';
  };

  const closeDrawer = () => {
    drawer.classList.remove('open');
    overlay.classList.remove('open');
    document.body.style.overflow = '';
  };

  mobileToggle.addEventListener('click', openDrawer);
  overlay.addEventListener('click', closeDrawer);
  if (closeBtn) closeBtn.addEventListener('click', closeDrawer);
}

/* --- 4. Table of Contents & ScrollSpy --- */
function initTOCScrollSpy() {
  const tocLinks = document.querySelectorAll('.toc-link');
  const sections = document.querySelectorAll('.article-content h2[id], .article-content h3[id]');

  if (!tocLinks.length || !sections.length) return;

  const observerOptions = {
    root: null,
    rootMargin: '-80px 0px -65% 0px',
    threshold: 0
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const id = entry.target.getAttribute('id');
        tocLinks.forEach(link => {
          if (link.getAttribute('href') === `#${id}`) {
            link.classList.add('active');
          } else {
            link.classList.remove('active');
          }
        });
      }
    });
  }, observerOptions);

  sections.forEach(sec => observer.observe(sec));
}

/* --- 5. FAQ Accordion --- */
function initFaqAccordion() {
  const faqItems = document.querySelectorAll('.faq-item');

  faqItems.forEach(item => {
    const questionBtn = item.querySelector('.faq-question');
    if (!questionBtn) return;

    questionBtn.addEventListener('click', () => {
      const isOpen = item.classList.contains('open');
      
      // Close other opened items
      faqItems.forEach(other => {
        if (other !== item) other.classList.remove('open');
      });

      if (isOpen) {
        item.classList.remove('open');
      } else {
        item.classList.add('open');
      }
    });
  });
}

/* --- 6. Live Search on Legal Hub (`index.html`) --- */
function initHubSearch() {
  const searchInput = document.getElementById('hubSearchInput');
  const hubCards = document.querySelectorAll('.hub-card');
  const noResultsMsg = document.getElementById('noSearchResults');

  if (!searchInput || !hubCards.length) return;

  searchInput.addEventListener('input', (e) => {
    const query = e.target.value.toLowerCase().trim();
    let visibleCount = 0;

    hubCards.forEach(card => {
      const text = card.textContent.toLowerCase();
      if (!query || text.includes(query)) {
        card.style.display = 'flex';
        visibleCount++;
      } else {
        card.style.display = 'none';
      }
    });

    if (noResultsMsg) {
      noResultsMsg.style.display = visibleCount === 0 ? 'block' : 'none';
    }
  });
}

/* --- 7. Data Deletion Form Handler --- */
function initDataDeletionForm() {
  const form = document.getElementById('dataDeletionForm');
  const successBox = document.getElementById('deletionSuccessBox');

  if (!form) return;

  form.addEventListener('submit', (e) => {
    e.preventDefault();

    const userId = (document.getElementById('deleteUserId')?.value || '').trim();
    const userEmail = (document.getElementById('deleteUserEmail')?.value || '').trim();
    const reason = (document.getElementById('deleteReason')?.value || '').trim();
    const confirmCheck = document.getElementById('deleteConfirmCheck');

    if (confirmCheck && !confirmCheck.checked) {
      showToast('Please check the confirmation box to proceed.');
      return;
    }

    // Construct mailto link for direct verification
    const subject = encodeURIComponent(`Data Deletion Request - RBX Rewards (${userId || userEmail})`);
    const body = encodeURIComponent(
      `Hello RBX Rewards Support Team,\n\n` +
      `I hereby request the complete permanent deletion of my account and all associated data in accordance with Google Play & Apple App Store Privacy Policies.\n\n` +
      `Account / User ID: ${userId || 'N/A'}\n` +
      `Associated Email: ${userEmail || 'N/A'}\n` +
      `Reason for Deletion: ${reason || 'User choice'}\n\n` +
      `I understand that this action is irreversible and forfeits any unused coin balance.\n\n` +
      `Thank you.`
    );

    // Open user's email client
    window.location.href = `mailto:privacy@rbxrewards.app?subject=${subject}&body=${body}`;

    if (successBox) {
      successBox.style.display = 'block';
      form.style.display = 'none';
    }

    showToast('Deletion request created. Dispatching via your email client.');
  });
}

/* --- 8. Share & Print Utilities --- */
function initShareAndPrint() {
  const printBtns = document.querySelectorAll('.btn-print');
  printBtns.forEach(btn => {
    btn.addEventListener('click', () => window.print());
  });

  const copyBtns = document.querySelectorAll('.btn-copy-link');
  copyBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      navigator.clipboard.writeText(window.location.href).then(() => {
        showToast('Page link copied to clipboard!');
      }).catch(() => {
        showToast('Could not copy link.');
      });
    });
  });
}

/* --- 9. Toast Notification --- */
function showToast(message) {
  let toast = document.querySelector('.toast-msg');
  if (!toast) {
    toast = document.createElement('div');
    toast.className = 'toast-msg';
    document.body.appendChild(toast);
  }

  toast.innerHTML = `
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2.5">
      <path d="M20 6 9 17l-5-5"/>
    </svg>
    <span>${message}</span>
  `;
  toast.classList.add('show');

  setTimeout(() => {
    toast.classList.remove('show');
  }, 3200);
}
