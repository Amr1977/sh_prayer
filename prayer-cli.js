// prayer-cli.js
import fetch from 'node-fetch';
import chalk from 'chalk';
import { execSync, spawn } from 'child_process';
import readline from 'readline';
import { fileURLToPath } from 'url';
import path from 'path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const VERSION = '1.0.0';

// CLI Interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

let intervalId;

function log(msg) {
  const now = new Date().toISOString().replace('T', ' ').split('.')[0];
  console.log(`${chalk.gray(`[${now}]`)} ${msg}`);
}

function say(text) {
  try {
    const proc = spawn('festival', ['--pipe']);
    proc.stdin.write(`(voice_mb_us2)
`);
    proc.stdin.write(`(SayText "${text}")\n`);
    proc.stdin.end();
  } catch (err) {
    log(chalk.red('Festival TTS failed'));
  }
}

function pad(n) {
  return n < 10 ? '0' + n : n;
}

function formatTime24(dateStr) {
  const d = new Date(`1970-01-01T${dateStr}`);
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function getRemainingTime(prayerTime) {
  const now = new Date();
  const [h, m] = prayerTime.split(':').map(Number);
  const t = new Date(now);
  t.setHours(h, m, 0, 0);
  if (t < now) t.setDate(t.getDate() + 1);
  const diffMs = t - now;
  const min = Math.floor(diffMs / 60000);
  return `${Math.floor(min / 60)}h ${min % 60}m`;
}

function calcLastThird(fajr, isha) {
  const fajrDate = new Date();
  const [fH, fM] = fajr.split(':').map(Number);
  fajrDate.setHours(fH, fM, 0, 0);

  const ishaDate = new Date();
  const [iH, iM] = isha.split(':').map(Number);
  ishaDate.setHours(iH, iM, 0, 0);
  if (ishaDate > fajrDate) ishaDate.setDate(ishaDate.getDate() - 1);

  const nightDuration = fajrDate - ishaDate;
  const lastThirdStart = new Date(fajrDate - nightDuration / 3);

  return `${pad(lastThirdStart.getHours())}:${pad(lastThirdStart.getMinutes())}`;
}

async function getLocation() {
  try {
    const res = await fetch('http://ip-api.com/json');
    const json = await res.json();
    return { city: json.city, country: json.countryCode };
  } catch (e) {
    log(chalk.red('Failed to get location'));
    return { city: 'Alexandria', country: 'EG' }; // fallback
  }
}

async function getPrayerTimes(city, country) {
  try {
    const res = await fetch(`https://muslimsalat.com/${city},${country}/daily.json?key=API_KEY`);
    const json = await res.json();
    const times = json.items[0];
    return {
      fajr: formatTime24(times.fajr),
      dhuhr: formatTime24(times.dhuhr),
      asr: formatTime24(times.asr),
      maghrib: formatTime24(times.maghrib),
      isha: formatTime24(times.isha),
      sunrise: formatTime24(times.shurooq || '05:44'), // fallback if not present
    };
  } catch (e) {
    log(chalk.red('Failed to fetch prayer times'));
    process.exit(1);
  }
}

async function announceNextPrayer(times) {
  const now = new Date();
  const entries = Object.entries(times);
  const upcoming = entries.find(([k, t]) => {
    const [h, m] = t.split(':').map(Number);
    const d = new Date();
    d.setHours(h, m, 0, 0);
    return d > now;
  }) || entries[0];

  const [name, time] = upcoming;
  const remaining = getRemainingTime(time);
  log(`🕒 ${chalk.cyan(name.toUpperCase())} prayer in ${remaining}`);
  say(`${name} prayer in ${remaining}`);
}

async function main() {
  log(chalk.yellow('🔃 Starting SHPrayer CLI'));

  const loc = await getLocation();
  log(`📍 Location: ${loc.city},${loc.country}`);

  const times = await getPrayerTimes(loc.city, loc.country);

  console.log(chalk.bold('📅 Prayer Times for Today:'));
  for (const [k, v] of Object.entries(times)) {
    console.log(`  ${k.padEnd(7)}: ${v}`);
  }

  log(`🌞 DST is ${Intl.DateTimeFormat().resolvedOptions().timeZone.includes('DST') ? 'active' : 'not active'}`);

  const lastThird = calcLastThird(times.fajr, times.isha);
  log(`🌙 Last third of the night starts at ${lastThird}`);

  log(`\n🔧 Version: ${VERSION}`);

  await announceNextPrayer(times);

  rl.setPrompt('> ');
  rl.prompt();

  intervalId = setInterval(async () => {
    await announceNextPrayer(times);
  }, 10 * 60 * 1000);

  rl.on('line', (line) => {
    if (line.trim().toLowerCase() === 'exit') {
      clearInterval(intervalId);
      rl.close();
    }
    rl.prompt();
  });

  rl.on('close', () => {
    log(chalk.red('🛑 Exiting Prayer CLI'));
    process.exit(0);
  });
}

main();
