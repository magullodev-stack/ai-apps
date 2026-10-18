// Maintain the upstream transport and HTML; add session identity and restoration.
const vscode = require('vscode');
const { probeAndroidBoot, waitForBoot } = require('./boot-ready.cjs');

function createViews(Base, context, sdk, devices, log) {
  class SessionViews extends Base {
    constructor() {
      super(context, sdk, devices, log);
      this.sessions = new Map();
      this.pending = new Map();
      this.restoredCount = 0;
      // Finite startup recovery, never an endless scrcpy retry loop.
      this.retryDelays = [1500, 3000, 6000];
      context.subscriptions.push(vscode.window.registerWebviewPanelSerializer('embedroid.embedded', {
        deserializeWebviewPanel: (panel, state) => this.restore(panel, state)
      }));
    }
    identity(serial) {
      return this.sessions.get(serial) || { serial, appId: '', label: serial };
    }
    title(session) { return `${session.label} · ${session.serial}`; }
    createPanel(key, title) {
      const panel = vscode.window.createWebviewPanel('embedroid.embedded', title,
        this.sessions.has(key) && this.views.size ? vscode.ViewColumn.Beside : this.targetColumn(),
        { enableScripts: true, retainContextWhenHidden: true,
          localResourceRoots: [vscode.Uri.joinPath(context.extensionUri, 'media')] });
      return this.adopt(panel, key, title);
    }
    adopt(panel, key, title) {
      // VS Code may restore a retired app title. Reset it before attaching
      // scrcpy so a transport failure cannot leave that stale title visible.
      panel.title = title;
      panel.webview.options = { enableScripts: true,
        localResourceRoots: [vscode.Uri.joinPath(context.extensionUri, 'media')] };
      panel.iconPath = vscode.Uri.joinPath(context.extensionUri, 'media', 'activitybar-icon.svg');
      const view = {
        key, panel, ready: false, queue: [], closed: false,
        retryCount: 0, retryTimer: null, attachPromise: null
      };
      this.views.set(key, view);
      panel.webview.onDidReceiveMessage(message => {
        if (message?.type === 'ready') {
          view.ready = true;
          for (const item of view.queue.splice(0)) panel.webview.postMessage(item);
        } else if (message?.type === 'retry') {
          this.cancelRetry(view);
          view.retryCount = 0;
          void this.retry(view);
        } else if (message?.type === 'streamError') this.scheduleRetry(view);
        else if (message?.type === 'frame' && Number.isInteger(message.frames) && message.frames > 0) {
          view.videoFrames = message.frames;
          view.lastFrameAt = Date.now();
        }
      });
      panel.onDidDispose(() => {
        view.closed = true;
        this.cancelRetry(view);
        view.bridge?.dispose().catch(error => log.warn(String(error)));
        if (this.views.get(view.key) === view) this.views.delete(view.key);
        log.debug(`Embedded view disposed (${view.key})`);
      });
      panel.webview.html = this.html(panel.webview, title);
      return view;
    }
    cancelRetry(view) {
      if (view.retryTimer) clearTimeout(view.retryTimer);
      view.retryTimer = null;
    }
    scheduleRetry(view) {
      // Recovery is only automatic before the first video frame, e.g. after
      // a restored tab races Android cold boot. Later errors remain actionable.
      if (view.closed || view.videoFrames > 0 || view.retryTimer ||
          view.retryCount >= this.retryDelays.length) return;
      const delay = this.retryDelays[view.retryCount++];
      this.send(view, { type: 'status',
        message: 'Reconectando vídeo (' + view.retryCount + '/' +
          this.retryDelays.length + ')…' });
      view.retryTimer = setTimeout(() => {
        view.retryTimer = null;
        if (view.closed || this.views.get(view.key) !== view) return;
        void this.retry(view);
      }, delay);
    }
    async waitForDeviceBoot(view, serial) {
      const { adb } = await this.sdk.resolve();
      this.send(view, { type: 'status', message: 'Esperando a que Android arranque…' });
      return waitForBoot({
        probe: () => probeAndroidBoot(adb, serial),
        isClosed: () => view.closed || this.views.get(view.key) !== view
      });
    }
    async attachStream(key, serial) {
      const view = this.views.get(key);
      if (!view || view.closed) return;
      if (view.attachPromise) return view.attachPromise;
      this.cancelRetry(view);
      const operation = (async () => {
        try {
          const ready = await this.waitForDeviceBoot(view, serial);
          if (!ready || view.closed || this.views.get(key) !== view) return;
          view.videoFrames = 0;
          view.lastFrameAt = 0;
          await super.attachStream(key, serial);
          if (view.closed) { await view.bridge?.dispose(); return; }
          const session = this.identity(serial);
          view.panel.title = this.title(session);
          this.send(view, { type: 'session', session });
        } catch (error) {
          if (!view.closed) this.fail(serial, String(error.message || error));
          throw error;
        }
      })();
      view.attachPromise = operation;
      try { await operation; }
      finally { if (view.attachPromise === operation) view.attachPromise = null; }
    }
    async openSession(session, reconnect = false) {
      if (!session || typeof session.serial !== 'string' || !session.serial ||
          typeof session.appId !== 'string' || typeof session.label !== 'string') {
        throw new Error('Invalid Android session identity');
      }
      const existing = this.sessions.get(session.serial);
      if (existing?.appId && existing.appId !== session.appId) throw new Error('Device already belongs to another application');
      this.sessions.set(session.serial, { serial: session.serial, appId: session.appId, label: session.label,
        ...(session.avdName ? { avdName: session.avdName } : {}) });
      if (this.pending.has(session.serial)) return this.pending.get(session.serial);
      const operation = (async () => {
        const view = this.views.get(session.serial);
        if (view) {
          view.panel.title = this.title(session);
          this.send(view, { type: 'session', session: this.identity(session.serial) });
          view.panel.reveal(undefined, true);
          if (reconnect) await this.attachStream(session.serial, session.serial);
        } else await super.open(session.serial);
      })();
      this.pending.set(session.serial, operation);
      try { await operation; } finally { this.pending.delete(session.serial); }
    }
    async restore(panel, state) {
      this.restoredCount++;
      // Persist only the device serial, not an application label or appId.
      // Panels saved by an older format have no serial-only state: dispose
      // them and let the current registry open a clean view.
      const serial = state?.serial;
      if (typeof serial !== 'string' || !serial) {
        panel.dispose();
        return;
      }
      if (this.views.has(serial)) { panel.dispose(); return; }
      // emulator-5554 is exclusively reserved for Muondia. Display its
      // definitive title immediately, even before the first video frame.
      // Other device names are resolved by the application registry.
      const pending = serial === 'emulator-5554'
        ? { serial, appId: 'muondia', label: 'Muondia' }
        : { serial, appId: '', label: 'Android' };
      this.sessions.set(serial, pending);
      const view = this.adopt(panel, serial, this.title(pending));
      view.serial = serial;
      await this.attachStream(serial, serial).catch(error => log.warn(String(error)));
    }
    listSessions() {
      return [...this.views.values()].filter(view => view.serial).map(view => ({
        ...this.identity(view.serial), title: view.panel.title,
        videoFrames: view.videoFrames || 0, lastFrameAt: view.lastFrameAt || 0
      }));
    }
  }
  return new SessionViews();
}
module.exports = { createViews };
