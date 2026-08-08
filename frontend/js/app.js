document.addEventListener('DOMContentLoaded', () => {
  const ledStatus = document.getElementById('ledStatus');
  const statusText = document.getElementById('statusText');
  const btnOpenSettings = document.getElementById('btnOpenSettings');
  const settingsModal = document.getElementById('settingsModal');
  const btnCloseSettingsModal = document.getElementById('btnCloseSettingsModal');
  const tvSelectDropdown = document.getElementById('tvSelectDropdown');
  const btnAutoDiscover = document.getElementById('btnAutoDiscover');
  const modalTvIp = document.getElementById('modalTvIp');
  const btnStartPair = document.getElementById('btnStartPair');
  const modalPinCode = document.getElementById('modalPinCode');
  const btnFinishPair = document.getElementById('btnFinishPair');
  const consoleLog = document.getElementById('consoleLog');
  const btnClearLog = document.getElementById('btnClearLog');

  let audioCtx = null;
  let savedTvIp = localStorage.getItem('heran_tv_ip') || '';
  if (savedTvIp) {
    modalTvIp.value = savedTvIp;
  }

  // Sound effect
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

  // Haptics
  function triggerHaptics() {
    if (navigator.vibrate) {
      navigator.vibrate(20);
    }
  }

  // Logger
  function addLog(text, type = 'key') {
    const time = new Date().toLocaleTimeString('zh-TW', { hour12: false });
    const div = document.createElement('div');
    div.className = `log-entry log-${type}`;
    div.textContent = `[${time}] ${text}`;
    consoleLog.appendChild(div);
    consoleLog.scrollTop = consoleLog.scrollHeight;
  }

  // Check Connection Status on Load
  async function checkServerStatus() {
    try {
      const res = await fetch('/api/status');
      const data = await res.json();
      if (data.is_connected) {
        ledStatus.classList.add('connected');
        statusText.textContent = `已連線 (${data.tv_ip || '電視'})`;
      } else {
        ledStatus.classList.remove('connected');
        statusText.textContent = '未連線 (請至設定)';
      }
    } catch (e) {
      ledStatus.classList.remove('connected');
      statusText.textContent = '伺服器未連線';
    }
  }

  // Auto Discover Devices in Settings
  async function performAutoDiscover() {
    btnAutoDiscover.disabled = true;
    btnAutoDiscover.innerHTML = `<span>搜尋中...</span>`;
    addLog('🔍 正在掃描區域網路內的 Google TV 設備...', 'system');

    try {
      const res = await fetch('/api/discover');
      const data = await res.json();
      btnAutoDiscover.disabled = false;
      btnAutoDiscover.innerHTML = `<span>重新搜尋</span>`;

      if (data.devices && data.devices.length > 0) {
        tvSelectDropdown.innerHTML = `<option value="">📺 找到 ${data.devices.length} 台電視 (點此選取)...</option>`;
        data.devices.forEach(d => {
          const opt = document.createElement('option');
          opt.value = d.ip;
          opt.textContent = `📺 ${d.name}`;
          tvSelectDropdown.appendChild(opt);
        });
        addLog(`🎉 成功找到 ${data.devices.length} 台電視設備！`, 'hint');

        // Auto select first device
        const first = data.devices[0];
        modalTvIp.value = first.ip;
        localStorage.setItem('heran_tv_ip', first.ip);
      } else {
        tvSelectDropdown.innerHTML = `<option value="">⚠️ 尚未自動偵測到，請手動輸入 IP</option>`;
        addLog('ℹ️ 區網內未回報電視，請手動輸入 IP', 'system');
      }
    } catch (e) {
      btnAutoDiscover.disabled = false;
      btnAutoDiscover.innerHTML = `<span>重新搜尋</span>`;
      addLog(`❌ 搜尋失敗: ${e.message}`, 'system');
    }
  }

  // Open / Close Settings Modal
  btnOpenSettings.addEventListener('click', () => {
    settingsModal.classList.add('open');
    performAutoDiscover();
  });
  btnCloseSettingsModal.addEventListener('click', () => {
    settingsModal.classList.remove('open');
  });

  btnAutoDiscover.addEventListener('click', performAutoDiscover);

  // Dropdown selection
  tvSelectDropdown.addEventListener('change', (e) => {
    const selectedIp = e.target.value;
    if (selectedIp) {
      modalTvIp.value = selectedIp;
      localStorage.setItem('heran_tv_ip', selectedIp);
      addLog(`已選擇電視: ${selectedIp}`, 'hint');
    }
  });

  // Start PIN Pairing
  btnStartPair.addEventListener('click', async () => {
    const ip = modalTvIp.value.trim();
    if (!ip) {
      alert('請先選擇或輸入電視的 IP 位址');
      return;
    }
    localStorage.setItem('heran_tv_ip', ip);
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

  // Finish PIN Pairing & Save
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
        statusText.textContent = `已連線 (${modalTvIp.value || '禾聯電視'})`;
        addLog(`🎉 ${data.message}`, 'hint');
        settingsModal.classList.remove('open');
      } else {
        addLog(`⚠️ 驗證失敗: ${data.message}`, 'system');
        alert(data.message);
      }
    } catch (e) {
      addLog(`❌ 連線異常: ${e.message}`, 'system');
    }
  });

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
        ledStatus.classList.add('connected');
        statusText.textContent = '已連線 (禾聯電視)';
        addLog(`✅ 電視已響應: ${keyName}`, 'key');
      } else {
        addLog(`⚠️ ${data.message || '已發送'}`, 'hint');
      }
    } catch (err) {
      addLog(`❌ 伺服器通訊異常: ${err.message}`, 'system');
    }
  }

  // Attach button events to all remote buttons
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

  // Clear log
  btnClearLog.addEventListener('click', () => {
    consoleLog.innerHTML = '';
  });

  // Check status on startup
  checkServerStatus();
});
