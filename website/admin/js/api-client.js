/**
 * RBX Rewards Admin API Client
 */
class AdminApiClient {
  constructor() {
    const configuredApi = (typeof AppConfig !== 'undefined' && AppConfig.apiBaseUrl) || (typeof window !== 'undefined' && window.API_BASE_URL) || window.location.origin;
    this.baseUrl = configuredApi.replace(/\/$/, '') + '/api/v1';
    this.tokenKey = 'rbx_admin_jwt_token';
  }

  getToken() {
    return localStorage.getItem(this.tokenKey);
  }

  setToken(token) {
    localStorage.setItem(this.tokenKey, token);
  }

  clearToken() {
    localStorage.removeItem(this.tokenKey);
  }

  isAuthenticated() {
    return Boolean(this.getToken());
  }

  async request(endpoint, options = {}) {
    const url = `${this.baseUrl}${endpoint}`;
    const headers = {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    };

    const token = this.getToken();
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    const response = await fetch(url, {
      ...options,
      headers,
    });

    const data = await response.json().catch(() => ({}));

    if (!response.ok) {
      const errorMsg = data?.error?.message || `Request failed with status ${response.status}`;
      if (response.status === 401 && !endpoint.includes('/auth/login')) {
        this.clearToken();
        window.dispatchEvent(new CustomEvent('admin:unauthorized'));
      }
      throw new Error(errorMsg);
    }

    return data.data;
  }

  // Auth Endpoints
  async login(email, password) {
    const res = await this.request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
    if (res?.accessToken) {
      this.setToken(res.accessToken);
    }
    return res;
  }

  async getSession() {
    return this.request('/auth/session');
  }

  // Anti-Fraud Endpoints
  async getFraudAlerts() {
    return this.request('/anti-fraud/alerts');
  }

  async getFlaggedUsers() {
    return this.request('/anti-fraud/flagged-users');
  }

  async getClusters() {
    return this.request('/anti-fraud/clusters');
  }

  async banUser(userId, reason) {
    return this.request('/anti-fraud/ban', {
      method: 'POST',
      body: JSON.stringify({ userId, reason }),
    });
  }

  async unbanUser(userId) {
    return this.request('/anti-fraud/unban', {
      method: 'POST',
      body: JSON.stringify({ userId }),
    });
  }

  // Redemptions Endpoints
  async getRedemptions(status = 'all', take = 50, skip = 0) {
    return this.request(`/redemptions?status=${status}&take=${take}&skip=${skip}`);
  }

  async dispatchPin(redemptionId, pinCode, adminNotes) {
    return this.request('/redemptions/dispatch', {
      method: 'POST',
      body: JSON.stringify({ redemptionId, pinCode, adminNotes }),
    });
  }

  async rejectReward(redemptionId, reason) {
    return this.request('/redemptions/reject', {
      method: 'POST',
      body: JSON.stringify({ redemptionId, reason }),
    });
  }

  // Economy Endpoints
  async getEconomyConfigs() {
    return this.request('/economy');
  }

  async updateMiniGameCaps(caps) {
    return this.request('/economy/caps', {
      method: 'POST',
      body: JSON.stringify(caps),
    });
  }

  async updateGlobalCap(cap) {
    return this.request('/economy/global-cap', {
      method: 'POST',
      body: JSON.stringify({ cap }),
    });
  }

  async updateRewardCard(id, coinPrice, inStock) {
    return this.request('/economy/card', {
      method: 'POST',
      body: JSON.stringify({ id, coinPrice, inStock }),
    });
  }

  // Performance Endpoints
  async getTelemetry() {
    return this.request('/performance/telemetry');
  }

  async purgeCache(target) {
    return this.request('/performance/purge', {
      method: 'POST',
      body: JSON.stringify({ target }),
    });
  }

  async updateTtl(leaderboardTtlSeconds, economyTtlSeconds = 300) {
    return this.request('/performance/ttl', {
      method: 'POST',
      body: JSON.stringify({ leaderboardTtlSeconds, economyTtlSeconds }),
    });
  }

  // Compliance Endpoints
  async getDeletionQueue() {
    return this.request('/compliance/deletion-queue');
  }

  async executePurge(requestId) {
    return this.request('/compliance/purge-user', {
      method: 'POST',
      body: JSON.stringify({ requestId }),
    });
  }

  async getSupportTickets(status = 'all') {
    return this.request(`/compliance/tickets?status=${status}`);
  }

  async resolveTicket(ticketId, status) {
    return this.request('/compliance/resolve-ticket', {
      method: 'POST',
      body: JSON.stringify({ ticketId, status }),
    });
  }

  // Audit Logs
  async getAuditLogs(take = 25, skip = 0) {
    return this.request(`/audit?take=${take}&skip=${skip}`);
  }
}

window.apiClient = new AdminApiClient();
