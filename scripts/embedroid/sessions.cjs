// Maintain the upstream transport and HTML; add session identity and restoration.
const vscode = require('vscode');

function createViews(Base, context, sdk, devices, log) {
  class SessionViews extends Base {
    constructor() {
      super(context, sdk, devices, log);
      this.sessions = new Map();
      this.pending = new Map();
      this.restoredCount = 0;
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
      const view = { key, panel, ready: false, queue: [] };
      this.views.set(key, view);
      panel.webview.onDidReceiveMessage(message => {
        if (message?.type === 'ready') {
          view.ready = true;
          for (const item of view.queue.splice(0)) panel.webview.postMessage(item);
        } else if (message?.type === 'retry') this.retry(view);
        else if (message?.type === 'frame' && Number.isInteger(message.frames) && message.frames > 0) {
          view.videoFrames = message.frames;
          view.lastFrameAt = Date.now();
        }
      });
      panel.onDidDispose(() => {
        view.closed = true;
        view.bridge?.dispose().catch(error => log.warn(String(error)));
        if (this.views.get(view.key) === view) this.views.delete(view.key);
        log.debug(`Embedded view disposed (${view.key})`);
      });
      panel.webview.html = this.html(panel.webview, title);
      return view;
    }
    async attachStream(key, serial) {
      const view = this.views.get(key);
      if (!view || view.closed) return;
      view.videoFrames = 0;
      view.lastFrameAt = 0;
      try {
        await super.attachStream(key, serial);
        if (view.closed) { await view.bridge?.dispose(); return; }
        const session = this.identity(serial);
        view.panel.title = this.title(session);
        this.send(view, { type: 'session', session });
      } catch (error) {
        if (!view.closed) this.fail(serial, String(error.message || error));
        throw error;
      }
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
          // A restored tab is just a view. AI-APPS Android attaches video
          // after its single Windows-owned development task reports Muondia live.
          if (!view.bridge || reconnect) await this.attachStream(session.serial, session.serial);
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
      // VS Code can restore tabs before the login task boots Android.
      // Never start scrcpy here: the owner of Android decides when it is ready.
      this.send(view, { type: 'status', message: 'Esperando a Muondia…' });
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
