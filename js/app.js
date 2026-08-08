document.addEventListener('DOMContentLoaded', () => {
  const ledStatus = document.getElementById('ledStatus');
  const statusText = document.getElementById('statusText');
  const tvIpInput = document.getElementById('tvIpInput');
  const btnQuickConnect = document.getElementById('btnQuickConnect');
  const btnOpenPairModal = document.getElementById('btnOpenPairModal');
  const pairModal = document.getElementById('pairModal');
  const btnClosePairModal = document.getElementById('btnClosePairModal');
  const modalTvIp = document.getElementById('modalTvIp');
  const btnStartPair = document.getElementById('btnStartPair');
  const modalPinCode = document.getElementById('modalPinCode');
  const btnFinishPair = document.getElementById('btnFinishPair');
  const consoleLog = document.getElementById('consoleLog');
  const btnClearLog = document.getElementById('btnClearLog');

  let audioCtx = null;
  let savedTvIp = localStorage.getItem('heran_tv_ip') || '';
  if (savedTvIp) {
    tvIpInput.value = savedTvIp;
    modalTvIp.value = savedTvIp;
  }

  // Helper: Sound effect
  function playClickSound() {
    try {
      if (!audioCtx) {
        audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      }
      if (audioCtx.state === 'suspended') {
        audioCtx.resume();
      }
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(750, audioCtx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(320, audioCtx.currentTime + 0.04);
      gain.gain.setValueAtTime(0.12, audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.04);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start();
      osc.stop(audioCtx.currentTime + 0.04);
    } catch (e) {}
  }

  // Helper: Haptics
  function triggerHaptics() {
    if (navigator.vibrate) {
      navigator.vibrate(20);
    }
  }

  // Helper: Logger
  function addLog(text, type = 'key') {
    const time = new Date().toLocaleTimeString('zh-TW', { hour12: false });
    const div = document.createElement('div');
    div.className = `log-entry log-${type}`;
    div.textContent = `[${time}] ${text}`;
    consoleLog.appendChild(div);
    consoleLog.scrollTop = consoleLog.scrollHeight;
  }

  // Send Remote Key via Backend REST API
  async function sendKey(keyName) {
    playClickSound();
    triggerHaptics();
    addLog(`發送指令: ${keyName}...`, 'key');

    try {
      const res = await fetch('/api/send_key', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ key: keyName })
      });
      const data = await res.json();
      if (data.status === 'success') {
        addLog(`✅ 電視已響應: ${keyName}`, 'key');
      } else {
        addLog(`⚠️ 發送反饋: ${data.message || '已發送'}`, 'hint');
      }
    } catch (err) {
      addLog(`❌ 連線伺服器異常: ${err.message}`, 'system');
    }
  }

  // Attach button events
  document.querySelectorAll('[data-key]').forEach(btn => {
    const key = btn.getAttribute('data-key');
    btn.addEventListener('touchstart', (e) => {
      e.preventDefault();
      sendKey(key);
    });
    btn.addEventListener('click', () => {
      sendKey(key);
    });
  });

  // Modal open/close
  btnOpenPairModal.addEventListener('click', () => {
    pairModal.classList.add('open');
  });
  btnClosePairModal.addEventListener('click', () => {
    pairModal.classList.remove('open');
  });

  // Start PIN Pairing
  btnStartPair.addEventListener('click', async () => {
    const ip = modalTvIp.value.trim();
    if (!ip) {
      alert('請先輸入電視的 IP 位址');
      return;
    }
    localStorage.setItem('heran_tv_ip', ip);
    tvIpInput.value = ip;
    addLog(`正在向電視 ${ip} 請求 PIN 碼配對...`, 'system');

    try {
      const res = await fetch('/api/pair/start', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ tv_ip: ip })
      });
      const data = await res.json();
      addLog(`📡 ${data.message}`, 'hint');
      modalPinCode.focus();
    } catch (e) {
      addLog(`❌ 配對請求失敗: ${e.message}`, 'system');
    }
  });

  // Finish PIN Pairing
  btnFinishPair.addEventListener('click', async () => {
    const pin = modalPinCode.value.trim();
    if (!pin) {
      alert('請輸入電視螢幕上顯示的 6 位數 PIN 碼');
      return;
    }
    addLog(`正在驗證 PIN 碼: ${pin}...`, 'system');

    try {
      const res = await fetch('/api/pair/finish', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ pin: pin })
      });
      const data = await res.json();
      if (data.status === 'success') {
        ledStatus.classList.add('connected');
        statusText.textContent = '已連線 (禾聯電視)';
        addLog(`🎉 ${data.message}`, 'hint');
        pairModal.classList.remove('open');
      } else {
        addLog(`⚠️ 驗證失敗: ${data.message}`, 'system');
        alert(data.message);
      }
    } catch (e) {
      addLog(`❌ 連線異常: ${e.message}`, 'system');
    }
  });

  // Quick Connect
  btnQuickConnect.addEventListener('click', async () => {
    const ip = tvIpInput.value.trim();
    if (!ip) {
      alert('請先輸入電視 IP 位址');
      return;
    }
    localStorage.setItem('heran_tv_ip', ip);
    addLog(`正在連線至電視 ${ip}...`, 'system');

    try {
      const res = await fetch('/api/connect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ tv_ip: ip })
      });
      const data = await res.json();
      if (data.status === 'success') {
        ledStatus.classList.add('connected');
        statusText.textContent = `已連線 (${ip})`;
        addLog(`✅ ${data.message}`, 'hint');
      } else {
        addLog(`ℹ️ ${data.message}`, 'hint');
      }
    } catch (e) {
      addLog(`❌ 連線失敗: ${e.message}`, 'system');
    }
  });

  // Clear log
  btnClearLog.addEventListener('click', () => {
    consoleLog.innerHTML = '';
  });
});
