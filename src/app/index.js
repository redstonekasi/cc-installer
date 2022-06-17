const electron = require('electron');
const Module = require('module');
const path = require('path');

//#region Fix path and get original app
const basePath = path.join(path.dirname(require.main.filename), '..');
const originalPath = path.join(basePath, 'app.asar');

const originalPackage = require(path.resolve(
	path.join(originalPath, "package.json")
));

require.main.filename = path.join(originalPath, originalPackage.main);

electron.app.setAppPath(originalPath);
electron.app.name = originalPackage.name;
//#endregion

const electronCache = require.cache[require.resolve('electron')];

//#region CSP
electron.app.on('ready', () => {
	// Remove CSP
	electron.session.defaultSession.webRequest.onHeadersReceived(({ responseHeaders }, done) => {
		const cspHeaders = Object.keys(responseHeaders).filter(name =>
			name.toLowerCase().startsWith('content-security-policy')
		);

		for (const header of cspHeaders) {
			delete responseHeaders[header];
		}

		done({ responseHeaders });
	});

	// Prevent others from removing CSP
	electronCache.exports.session.defaultSession.webRequest.onHeadersReceived = () => {};
});
//#endregion

//#region Hook into discord window
async function injectionCode() {
	if (!window.cumcord && !window._cumcordInjecting) {
		window._cumcordInjecting = true;

		// Wait for discord to load
		const wpRequire = webpackChunkdiscord_app.push([[Symbol()], {}, (w) => w]);
	    webpackChunkdiscord_app.pop();
	    const checkModules = () => Object.values(wpRequire.c).some((m) => m.exports?.default?.getCurrentUser?.());
	    while (!checkModules()) await new Promise((r) => setTimeout(r, 100));

		eval(await (await fetch('https://raw.githubusercontent.com/Cumcord/builds/main/build.js', { cache: 'no-store' })).text())
		
		delete window._cumcordInjecting;
	}
}

// Create new electron with custom 'BrowserWindow'
const { BrowserWindow } = electron;
const propertyNames = Object.getOwnPropertyNames(electronCache.exports);

delete electronCache.exports;

const newElectron = {};

// Copy properties from original electron to new electron
for (const propertyName of propertyNames) {
	Object.defineProperty(newElectron, propertyName, {
		...Object.getOwnPropertyDescriptor(electron, propertyName),
		get: () => propertyName === 'BrowserWindow' ? class extends BrowserWindow {
			constructor(opts) {
				const window = new BrowserWindow(opts);

				if (window.title.startsWith('Discord')) {
					window.webContents.on('did-finish-load', () => {
						window.webContents.executeJavaScript(`(${injectionCode})();`);
					});
				}

				return window;
			}
		} : electron[propertyName]
	});
}

electronCache.exports = newElectron;
//#endregion

// Load original app
Module._load(path.join(__dirname, '..', 'app.asar'), null, true);
