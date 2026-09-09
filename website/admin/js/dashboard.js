document.addEventListener('DOMContentLoaded', () => {
  const api = window.apiClient;

  // DOM Elements
  const authGateModal = document.getElementById('authGateModal');
  const loginForm = document.getElementById('loginForm');
  const loginEmailInput = document.getElementById('loginEmail');
  const loginPasswordInput = document.getElementById('loginPassword');
  const loginErrorBanner = document.getElementById('loginErrorBanner');
  const logoutBtn = document.getElementById('logoutBtn');
  const headerAdminEmail = document.getElementById('headerAdminEmail');

  // Navigation
  const navItems = document.querySelectorAll('.nav-item');
  const tabPanes = document.querySelectorAll('.tab-pane');

  // Modals
  const dispatchModal = document.getElementById('dispatchPinModal');
  const dispatchForm = document.getElementById('dispatchPinForm');
  const dispatchPinInput = document.getElementById('dispatchPinInput');
  const dispatchRedemptionId = document.getElementById('dispatchRedemptionId');
  const dispatchCardDenom = document.getElementById('dispatchCardDenom');
  const dispatchUserEmail = document.getElementById('dispatchUserEmail');
  const dispatchPinError = document.getElementById('dispatchPinError');
  const cancelDispatchBtn = document.getElementById('cancelDispatchBtn');
  const closeDispatchModalBtn = document.getElementById('closeDispatchModalBtn');

  const rejectModal = document.getElementById('rejectModal');
  const rejectForm = document.getElementById('rejectForm');
  const rejectRedemptionId = document.getElementById('rejectRedemptionId');
  const rejectReasonInput = document.getElementById('rejectReasonInput');
  const cancelRejectBtn = document.getElementById('cancelRejectBtn');
  const closeRejectModalBtn = document.getElementById('closeRejectModalBtn');

  const banModal = document.getElementById('banModal');
  const banForm = document.getElementById('banForm');
  const banUserId = document.getElementById('banUserId');
  const banReasonInput = document.getElementById('banReasonInput');
  const cancelBanBtn = document.getElementById('cancelBanBtn');
  const closeBanModalBtn = document.getElementById('closeBanModalBtn');

  // Toast container
  const toastContainer = document.getElementById('toastContainer');

  function showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    toastContainer.appendChild(toast);
    setTimeout(() => toast.remove(), 4000);
  }

  // Theme Toggle (Light / Dark)
  const adminThemeToggleBtn = document.getElementById('adminThemeToggleBtn');
  const adminThemeIcon = document.getElementById('adminThemeIcon');
  const adminThemeText = document.getElementById('adminThemeText');

  function initAdminTheme() {
    const savedTheme = localStorage.getItem('rbx_admin_theme') || 'light';
    setAdminTheme(savedTheme);

    if (adminThemeToggleBtn) {
      adminThemeToggleBtn.addEventListener('click', () => {
        const current = document.documentElement.getAttribute('data-theme') || 'light';
        const next = current === 'light' ? 'dark' : 'light';
        setAdminTheme(next);
      });
    }
  }

  function setAdminTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('rbx_admin_theme', theme);
    if (adminThemeIcon && adminThemeText) {
      if (theme === 'light') {
        adminThemeIcon.textContent = '☀️';
        adminThemeText.textContent = 'Light';
      } else {
        adminThemeIcon.textContent = '🌙';
        adminThemeText.textContent = 'Dark';
      }
    }
  }

  initAdminTheme();

  // Check Authentication
  async function initAuth() {
    if (!api.isAuthenticated()) {
      authGateModal.classList.remove('hidden');
      return;
    }

    try {
      const session = await api.getSession();
      if (session?.admin?.email) {
        headerAdminEmail.textContent = session.admin.email;
        authGateModal.classList.add('hidden');
        loadAllData();
      } else {
        authGateModal.classList.remove('hidden');
      }
    } catch {
      api.clearToken();
      authGateModal.classList.remove('hidden');
    }
  }

  window.addEventListener('admin:unauthorized', () => {
    authGateModal.classList.remove('hidden');
    showToast('Session expired. Please sign in again.', 'error');
  });

  // Login handler
  loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    loginErrorBanner.classList.add('hidden');
    loginErrorBanner.textContent = '';

    const email = loginEmailInput.value.trim();
    const password = loginPasswordInput.value.trim();

    try {
      const res = await api.login(email, password);
      headerAdminEmail.textContent = res.admin.email;
      authGateModal.classList.add('hidden');
      loginForm.reset();
      showToast('Successfully authenticated to Admin Center');
      loadAllData();
    } catch (err) {
      loginErrorBanner.textContent = err.message || 'Authentication failed';
      loginErrorBanner.classList.remove('hidden');
    }
  });

  // Logout handler
  logoutBtn.addEventListener('click', () => {
    api.clearToken();
    authGateModal.classList.remove('hidden');
    showToast('Logged out of Admin Center');
  });

  // Tab Navigation
  navItems.forEach((btn) => {
    btn.addEventListener('click', () => {
      const tabKey = btn.getAttribute('data-tab');
      navItems.forEach((n) => n.classList.remove('active'));
      btn.classList.add('active');

      tabPanes.forEach((pane) => {
        if (pane.id === `tab-${tabKey}`) {
          pane.classList.add('active');
        } else {
          pane.classList.remove('active');
        }
      });
    });
  });

  // Load Overview Data
  async function loadOverview() {
    try {
      const redemptions = await api.getRedemptions('pending');
      const alerts = await api.getFraudAlerts();
      const telemetry = await api.getTelemetry();
      const deletionQueue = await api.getDeletionQueue();

      document.getElementById('metricPendingRedemptions').textContent = redemptions?.total ?? 0;
      document.getElementById('pendingRedeemCount').textContent = redemptions?.total ?? 0;
      document.getElementById('metricFraudAlerts').textContent = alerts?.length ?? 0;
      document.getElementById('fraudAlertCount').textContent = alerts?.length ?? 0;
      document.getElementById('metricRedisLatency').textContent = `${telemetry?.redisLatencyMs ?? 14} ms`;
      document.getElementById('metricDeletionCount').textContent = deletionQueue?.length ?? 0;

      // Table in overview
      const overviewTbody = document.getElementById('overviewRedemptionsTable');
      overviewTbody.innerHTML = '';
      (redemptions?.items || []).slice(0, 3).forEach((r) => {
        const tr = document.createElement('tr');
        const slaBadge = r.isSlaBreached
          ? '<span class="badge badge-danger">Breached</span>'
          : `<span class="badge ${r.slaHoursRemaining < 12 ? 'badge-warning' : 'badge-success'}">${r.slaHoursRemaining}h remaining</span>`;

        tr.innerHTML = `
          <td><strong>${r.userEmail}</strong></td>
          <td><span class="badge badge-primary">${r.denomination}</span></td>
          <td>${r.cost.toLocaleString()} coins</td>
          <td>${slaBadge}</td>
        `;
        overviewTbody.appendChild(tr);
      });

      // Alerts list in overview
      const alertsList = document.getElementById('overviewAlertsList');
      alertsList.innerHTML = '';
      (alerts || []).forEach((a) => {
        const div = document.createElement('div');
        div.className = 'notice-box mb-3';
        div.innerHTML = `
          <div class="flex-between">
            <strong>${a.alertType.replace('_', ' ').toUpperCase()}</strong>
            <span class="badge badge-danger">${a.severity.toUpperCase()}</span>
          </div>
          <div class="text-muted mt-2">${a.userEmail}</div>
        `;
        alertsList.appendChild(div);
      });
    } catch (err) {
      console.error('Failed to load overview metrics:', err);
    }
  }

  // Load Anti-Fraud Data
  async function loadAntiFraud() {
    try {
      const users = await api.getFlaggedUsers();
      const tbody = document.getElementById('flaggedUsersTableBody');
      tbody.innerHTML = '';

      users.forEach((u) => {
        const tr = document.createElement('tr');
        const statusBadge = u.isBanned
          ? '<span class="badge badge-danger">Banned</span>'
          : '<span class="badge badge-warning">Flagged Active</span>';

        const actionBtn = u.isBanned
          ? `<button class="btn btn-outline btn-sm unban-btn" data-user-id="${u.id}" data-testid="unban-btn-${u.id}">Unban</button>`
          : `<button class="btn btn-danger btn-sm ban-btn" data-user-id="${u.id}" data-testid="ban-btn-${u.id}">Freeze / Ban</button>`;

        tr.innerHTML = `
          <td><strong>${u.displayName}</strong></td>
          <td>${u.email}</td>
          <td><code>${u.deviceId || 'Unknown'}</code> ${u.isEmulator ? '<span class="badge badge-danger">Emulator</span>' : ''}</td>
          <td>${u.coinBalance.toLocaleString()}</td>
          <td data-testid="user-status-${u.id}">${statusBadge}</td>
          <td>${actionBtn}</td>
        `;
        tbody.appendChild(tr);
      });

      // Wire Ban & Unban buttons
      tbody.querySelectorAll('.ban-btn').forEach((b) => {
        b.addEventListener('click', () => {
          banUserId.value = b.getAttribute('data-user-id');
          banModal.classList.remove('hidden');
        });
      });

      tbody.querySelectorAll('.unban-btn').forEach((b) => {
        b.addEventListener('click', async () => {
          const uId = b.getAttribute('data-user-id');
          try {
            await api.unbanUser(uId);
            showToast('User account successfully unbanned');
            loadAntiFraud();
            loadOverview();
          } catch (err) {
            showToast(err.message, 'error');
          }
        });
      });

      // Clusters
      const clusters = await api.getClusters();
      const clustersContainer = document.getElementById('clustersContainer');
      clustersContainer.innerHTML = '';
      clusters.forEach((c) => {
        const box = document.createElement('div');
        box.className = 'card-item';
        box.innerHTML = `
          <div class="card-item-left">
            <span class="card-badge">🔗</span>
            <div>
              <strong>Device / Subnet: ${c.identifier}</strong>
              <div class="text-muted">${c.accountCount} Accounts Connected</div>
            </div>
          </div>
          <span class="badge badge-warning">Farm Cluster</span>
        `;
        clustersContainer.appendChild(box);
      });
    } catch (err) {
      console.error('Failed to load anti-fraud data:', err);
    }
  }

  // Ban Modal Form Submit
  banForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const userId = banUserId.value;
    const reason = banReasonInput.value.trim();
    try {
      await api.banUser(userId, reason);
      showToast('Account successfully banned & balance frozen');
      banModal.classList.add('hidden');
      banForm.reset();
      loadAntiFraud();
      loadOverview();
    } catch (err) {
      showToast(err.message, 'error');
    }
  });

  cancelBanBtn.addEventListener('click', () => banModal.classList.add('hidden'));
  closeBanModalBtn.addEventListener('click', () => banModal.classList.add('hidden'));

  // Load Redemptions Queue
  let currentFilter = 'all';
  async function loadRedemptions(status = currentFilter) {
    try {
      const res = await api.getRedemptions(status);
      const tbody = document.getElementById('redemptionsTableBody');
      tbody.innerHTML = '';

      (res?.items || []).forEach((r) => {
        const tr = document.createElement('tr');
        const slaClass = r.isSlaBreached ? 'badge-danger' : r.slaHoursRemaining < 12 ? 'badge-warning' : 'badge-success';
        const slaText = r.isSlaBreached ? 'Breached (>48h)' : `${r.slaHoursRemaining}h remaining`;

        let actionBtns = '—';
        if (r.status === 'pending') {
          actionBtns = `
            <button class="btn btn-primary btn-sm dispatch-btn" data-id="${r.id}" data-email="${r.userEmail}" data-denom="${r.denomination}" data-testid="dispatch-btn-${r.id}">
              Dispatch PIN
            </button>
            <button class="btn btn-outline btn-sm reject-btn" data-id="${r.id}" data-testid="reject-btn-${r.id}">
              Reject & Refund
            </button>
          `;
        }

        tr.innerHTML = `
          <td><code>${r.id.substring(0, 8)}...</code></td>
          <td><strong>${r.userEmail}</strong></td>
          <td><span class="badge badge-primary">${r.denomination}</span></td>
          <td>${r.cost.toLocaleString()}</td>
          <td data-testid="redemption-status-${r.id}"><span class="badge ${r.status === 'fulfilled' ? 'badge-success' : r.status === 'rejected' ? 'badge-danger' : 'badge-warning'}">${r.status.toUpperCase()}</span></td>
          <td><span class="badge ${slaClass}" data-testid="sla-badge-${r.id}">${slaText}</span></td>
          <td>${r.pinCode ? `<code>${r.pinCode}</code>` : r.adminNotes || '—'}</td>
          <td>${actionBtns}</td>
        `;
        tbody.appendChild(tr);
      });

      // Wire Dispatch buttons
      tbody.querySelectorAll('.dispatch-btn').forEach((b) => {
        b.addEventListener('click', () => {
          dispatchRedemptionId.value = b.getAttribute('data-id');
          dispatchUserEmail.textContent = b.getAttribute('data-email');
          dispatchCardDenom.textContent = b.getAttribute('data-denom');
          dispatchPinError.classList.add('hidden');
          dispatchModal.classList.remove('hidden');
        });
      });

      // Wire Reject buttons
      tbody.querySelectorAll('.reject-btn').forEach((b) => {
        b.addEventListener('click', () => {
          rejectRedemptionId.value = b.getAttribute('data-id');
          rejectModal.classList.remove('hidden');
        });
      });
    } catch (err) {
      console.error('Failed to load redemptions:', err);
    }
  }

  // Filter Buttons
  document.querySelectorAll('.filter-btn').forEach((b) => {
    b.addEventListener('click', () => {
      document.querySelectorAll('.filter-btn').forEach((f) => f.classList.remove('active'));
      b.classList.add('active');
      currentFilter = b.getAttribute('data-filter');
      loadRedemptions(currentFilter);
    });
  });

  // Dispatch PIN Submit
  dispatchForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    dispatchPinError.classList.add('hidden');
    const redemptionId = dispatchRedemptionId.value;
    const pinCode = dispatchPinInput.value.trim();
    const adminNotes = document.getElementById('dispatchNotesInput').value.trim();

    if (!pinCode || pinCode.length < 8) {
      dispatchPinError.textContent = 'Roblox PIN code must be at least 8 characters';
      dispatchPinError.classList.remove('hidden');
      return;
    }

    try {
      await api.dispatchPin(redemptionId, pinCode, adminNotes);
      showToast('PIN successfully dispatched to user');
      dispatchModal.classList.add('hidden');
      dispatchForm.reset();
      loadRedemptions(currentFilter);
      loadOverview();
    } catch (err) {
      dispatchPinError.textContent = err.message || 'Failed to dispatch PIN';
      dispatchPinError.classList.remove('hidden');
    }
  });

  cancelDispatchBtn.addEventListener('click', () => dispatchModal.classList.add('hidden'));
  closeDispatchModalBtn.addEventListener('click', () => dispatchModal.classList.add('hidden'));

  // Reject Submit
  rejectForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const redemptionId = rejectRedemptionId.value;
    const reason = rejectReasonInput.value.trim();

    try {
      await api.rejectReward(redemptionId, reason);
      showToast('Redemption rejected and coins refunded');
      rejectModal.classList.add('hidden');
      rejectForm.reset();
      loadRedemptions(currentFilter);
      loadOverview();
    } catch (err) {
      showToast(err.message, 'error');
    }
  });

  cancelRejectBtn.addEventListener('click', () => rejectModal.classList.add('hidden'));
  closeRejectModalBtn.addEventListener('click', () => rejectModal.classList.add('hidden'));

  // Load Economy Configs
  async function loadEconomy() {
    try {
      const data = await api.getEconomyConfigs();
      if (data?.miniGameCaps) {
        document.getElementById('capTapTap').value = data.miniGameCaps.tap_tap || 150;
        document.getElementById('capMathQuiz').value = data.miniGameCaps.math_quiz || 120;
        document.getElementById('capFlappyJump').value = data.miniGameCaps.flappy_jump || 150;
        document.getElementById('capFlipCards').value = data.miniGameCaps.flip_cards || 60;
        document.getElementById('capScratchCard').value = data.miniGameCaps.scratch_card || 100;
      }

      // Render Cards
      const cardsList = document.getElementById('rewardCardsList');
      cardsList.innerHTML = '';
      (data?.rewardCards?.cards || []).forEach((c) => {
        const cardBox = document.createElement('div');
        cardBox.className = 'card-item';
        cardBox.innerHTML = `
          <div class="card-item-left">
            <span class="card-badge">${c.denomination}</span>
            <div>
              <strong>${c.denomination} Roblox Gift Card</strong>
              <div class="text-muted"><span id="price-val-${c.id}">${c.coinPrice.toLocaleString()}</span> Coins Required</div>
            </div>
          </div>
          <div style="display:flex;gap:0.75rem;align-items:center;">
            <button class="btn btn-outline btn-sm toggle-stock-btn" data-id="${c.id}" data-instock="${c.inStock}" data-price="${c.coinPrice}" data-testid="toggle-stock-${c.id}">
              ${c.inStock ? 'In Stock' : 'Sold Out'}
            </button>
            <button class="btn btn-secondary btn-sm edit-price-btn" data-id="${c.id}" data-price="${c.coinPrice}" data-testid="edit-price-${c.id}">
              Edit Price
            </button>
          </div>
        `;
        cardsList.appendChild(cardBox);
      });

      // Stock Toggle Handlers
      cardsList.querySelectorAll('.toggle-stock-btn').forEach((b) => {
        b.addEventListener('click', async () => {
          const id = b.getAttribute('data-id');
          const currentStock = b.getAttribute('data-instock') === 'true';
          const price = parseInt(b.getAttribute('data-price'), 10);
          try {
            await api.updateRewardCard(id, price, !currentStock);
            showToast(`Card stock updated to ${!currentStock ? 'In Stock' : 'Sold Out'}`);
            loadEconomy();
          } catch (err) {
            showToast(err.message, 'error');
          }
        });
      });

      // Price Edit Handlers
      cardsList.querySelectorAll('.edit-price-btn').forEach((b) => {
        b.addEventListener('click', async () => {
          const id = b.getAttribute('data-id');
          const currentPrice = b.getAttribute('data-price');
          const newPriceStr = prompt(`Enter new coin price for ${id}:`, currentPrice);
          if (!newPriceStr) return;
          const newPrice = parseInt(newPriceStr, 10);
          if (isNaN(newPrice) || newPrice < 1000) {
            showToast('Price must be a valid number >= 1000', 'error');
            return;
          }
          try {
            await api.updateRewardCard(id, newPrice, true);
            showToast('Card price updated successfully');
            loadEconomy();
          } catch (err) {
            showToast(err.message, 'error');
          }
        });
      });
    } catch (err) {
      console.error('Failed to load economy configs:', err);
    }
  }

  // Save Caps Form Submit
  document.getElementById('capsForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const caps = {
      tap_tap: parseInt(document.getElementById('capTapTap').value, 10),
      math_quiz: parseInt(document.getElementById('capMathQuiz').value, 10),
      flappy_jump: parseInt(document.getElementById('capFlappyJump').value, 10),
      flip_cards: parseInt(document.getElementById('capFlipCards').value, 10),
      scratch_card: parseInt(document.getElementById('capScratchCard').value, 10),
    };

    try {
      await api.updateMiniGameCaps(caps);
      showToast('Daily mini-game caps saved successfully');
    } catch (err) {
      showToast(err.message, 'error');
    }
  });

  // Load Performance & Redis
  const leaderboardTtlSlider = document.getElementById('leaderboardTtl');
  const ttlDisplay = document.getElementById('ttlDisplay');
  leaderboardTtlSlider.addEventListener('input', (e) => {
    ttlDisplay.textContent = e.target.value;
  });

  async function loadPerformance() {
    try {
      const telemetry = await api.getTelemetry();
      document.getElementById('telemetryRedisPing').textContent = `${telemetry?.redisLatencyMs ?? 12} ms`;
      if (telemetry?.ttlSettings?.leaderboardTtlSeconds) {
        leaderboardTtlSlider.value = telemetry.ttlSettings.leaderboardTtlSeconds;
        ttlDisplay.textContent = telemetry.ttlSettings.leaderboardTtlSeconds;
      }
    } catch (err) {
      console.error('Failed to load performance metrics:', err);
    }
  }

  // Cache Purge Actions
  async function triggerPurge(target) {
    try {
      const res = await api.purgeCache(target);
      const notice = document.getElementById('purgeResultNotice');
      notice.textContent = `Successfully invalidated ${res.invalidatedCount} keys matching target [${target}] across edge nodes.`;
      notice.classList.remove('hidden');
      showToast(`Cache purged: ${res.invalidatedCount} keys invalidated`);
    } catch (err) {
      showToast(err.message, 'error');
    }
  }

  document.getElementById('purgeLeaderboardBtn').addEventListener('click', () => triggerPurge('leaderboard'));
  document.getElementById('purgeEconomyBtn').addEventListener('click', () => triggerPurge('economy'));
  document.getElementById('purgeAllBtn').addEventListener('click', () => triggerPurge('all'));

  // TTL Form Submit
  document.getElementById('ttlForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const ttl = parseInt(leaderboardTtlSlider.value, 10);
    try {
      await api.updateTtl(ttl);
      showToast('Cache TTL settings saved');
    } catch (err) {
      showToast(err.message, 'error');
    }
  });

  // Load Compliance Data
  async function loadCompliance() {
    try {
      const queue = await api.getDeletionQueue();
      const tbody = document.getElementById('deletionTableBody');
      tbody.innerHTML = '';

      queue.forEach((d) => {
        const tr = document.createElement('tr');
        const actionBtn = d.status === 'completed'
          ? '<span class="badge badge-success">Purged</span>'
          : `<button class="btn btn-danger btn-sm purge-user-btn" data-id="${d.id}" data-testid="purge-btn-${d.id}">Purge Now</button>`;

        tr.innerHTML = `
          <td><code>${d.id.substring(0, 8)}...</code></td>
          <td><strong>${d.email}</strong></td>
          <td>${d.reason}</td>
          <td><span class="badge badge-warning">${d.daysRemaining} days left</span></td>
          <td data-testid="deletion-status-${d.id}"><span class="badge ${d.status === 'completed' ? 'badge-success' : 'badge-danger'}">${d.status.toUpperCase()}</span></td>
          <td>${actionBtn}</td>
        `;
        tbody.appendChild(tr);
      });

      tbody.querySelectorAll('.purge-user-btn').forEach((b) => {
        b.addEventListener('click', async () => {
          const reqId = b.getAttribute('data-id');
          try {
            await api.executePurge(reqId);
            showToast('User data irrevocably purged per Google Play 7-day rule');
            loadCompliance();
            loadOverview();
          } catch (err) {
            showToast(err.message, 'error');
          }
        });
      });

      // Support Tickets
      const tickets = await api.getSupportTickets();
      const supportTbody = document.getElementById('supportTableBody');
      supportTbody.innerHTML = '';

      tickets.forEach((t) => {
        const tr = document.createElement('tr');
        const actionBtn = t.status === 'resolved'
          ? '<span class="badge badge-success">Resolved</span>'
          : `<button class="btn btn-outline btn-sm resolve-ticket-btn" data-id="${t.id}" data-testid="resolve-ticket-${t.id}">Mark Resolved</button>`;

        tr.innerHTML = `
          <td><strong>${t.subject}</strong></td>
          <td><span class="badge badge-primary">${t.category}</span></td>
          <td>${t.message}</td>
          <td data-testid="ticket-status-${t.id}"><span class="badge ${t.status === 'resolved' ? 'badge-success' : 'badge-warning'}">${t.status.toUpperCase()}</span></td>
          <td>${actionBtn}</td>
        `;
        supportTbody.appendChild(tr);
      });

      supportTbody.querySelectorAll('.resolve-ticket-btn').forEach((b) => {
        b.addEventListener('click', async () => {
          const tId = b.getAttribute('data-id');
          try {
            await api.resolveTicket(tId, 'resolved');
            showToast('Support ticket resolved');
            loadCompliance();
          } catch (err) {
            showToast(err.message, 'error');
          }
        });
      });
    } catch (err) {
      console.error('Failed to load compliance data:', err);
    }
  }

  // Load Audit Trail
  async function loadAudit() {
    try {
      const res = await api.getAuditLogs();
      const tbody = document.getElementById('auditTableBody');
      tbody.innerHTML = '';

      (res?.logs || []).forEach((log) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td><code>${new Date(log.createdAt).toLocaleTimeString()}</code></td>
          <td><strong>${log.adminEmail}</strong></td>
          <td><span class="badge badge-primary">${log.action}</span></td>
          <td>${log.targetType}</td>
          <td><code>${log.targetId.substring(0, 10)}...</code></td>
          <td>${JSON.stringify(log.details)}</td>
        `;
        tbody.appendChild(tr);
      });
    } catch (err) {
      console.error('Failed to load audit logs:', err);
    }
  }

  function loadAllData() {
    loadOverview();
    loadAntiFraud();
    loadRedemptions();
    loadEconomy();
    loadPerformance();
    loadCompliance();
    loadAudit();
  }

  document.getElementById('refreshOverviewBtn').addEventListener('click', loadOverview);

  // Initialize
  initAuth();
});
