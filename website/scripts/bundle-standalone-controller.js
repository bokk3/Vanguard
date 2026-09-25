import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const distDir = path.resolve(__dirname, '../dist');
const godotDir = path.resolve(__dirname, '../../godot_project');

function bundleStandalone() {
  const htmlPath = path.join(distDir, 'controller.html');
  if (!fs.existsSync(htmlPath)) {
    console.error('dist/controller.html not found! Run npm run build first.');
    process.exit(1);
  }

  let html = fs.readFileSync(htmlPath, 'utf8');

  // Find css file
  const assetsDir = path.join(distDir, 'assets');
  const files = fs.readdirSync(assetsDir);
  const cssFile = files.find(f => f.startsWith('style-') && f.endsWith('.css'));
  const jsFile = files.find(f => f.startsWith('controller-') && f.endsWith('.js'));

  if (!cssFile || !jsFile) {
    console.error('Could not find CSS or JS assets in dist/assets!');
    process.exit(1);
  }

  const cssContent = fs.readFileSync(path.join(assetsDir, cssFile), 'utf8');
  let jsContent = fs.readFileSync(path.join(assetsDir, jsFile), 'utf8');

  // Strip any ES import statements (e.g., import "./style-xxx.js") so script executes in standard inline <script>
  jsContent = jsContent.replace(/import\s*['"][^'"]+['"];?/g, '');

  // Remove script module and link rel stylesheet tags
  html = html.replace(/<script type="module"[^>]*><\/script>/gi, '');
  html = html.replace(/<link rel="modulepreload"[^>]*>/gi, '');
  html = html.replace(/<link rel="stylesheet"[^>]*>/gi, '');

  // Inject inline style before </head>
  html = html.replace('</head>', `<style>\n${cssContent}\n</style>\n</head>`);

  // Inject inline script before </body>
  html = html.replace('</body>', `<script>\n${jsContent}\n</script>\n</body>`);

  // Save to website/dist/controller_standalone.html
  const distOut = path.join(distDir, 'controller_standalone.html');
  fs.writeFileSync(distOut, html, 'utf8');
  console.log(`Saved ${distOut} (${(html.length / 1024).toFixed(1)} kB)`);

  // Save to godot_project/controller_standalone.html
  const godotOut = path.join(godotDir, 'controller_standalone.html');
  fs.writeFileSync(godotOut, html, 'utf8');
  console.log(`Saved ${godotOut} (${(html.length / 1024).toFixed(1)} kB)`);
}

bundleStandalone();
