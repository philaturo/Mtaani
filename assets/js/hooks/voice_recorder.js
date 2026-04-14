const VoiceRecorder = {
  mounted() {
    this.mediaRecorder = null;
    this.audioChunks = [];
    this.isRecording = false;
    this.recordingStartTime = null;
    this.recordingTimer = null;

    this.createVoiceButton();

    this.el.addEventListener("mousedown", this.startRecording.bind(this));
    this.el.addEventListener("mouseup", this.stopRecording.bind(this));
    this.el.addEventListener("mouseleave", this.cancelRecording.bind(this));
    this.el.addEventListener("touchstart", this.startRecording.bind(this));
    this.el.addEventListener("touchend", this.stopRecording.bind(this));
  },

  createVoiceButton() {
    const voiceBtn = document.createElement("button");
    voiceBtn.className = "voice-recorder-btn";
    voiceBtn.innerHTML = `
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m-4 0h8m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
      </svg>
    `;
    voiceBtn.style.cssText = `
      position: absolute;
      right: 60px;
      bottom: 12px;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      background: #2E6B46;
      border: none;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
    `;

    const inputContainer = this.el.closest(".chat-input-container");
    if (inputContainer) {
      inputContainer.style.position = "relative";
      inputContainer.appendChild(voiceBtn);
    }
  },

  async startRecording(e) {
    e.preventDefault();

    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      alert("Voice recording not supported in this browser");
      return;
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      this.mediaRecorder = new MediaRecorder(stream);
      this.audioChunks = [];

      this.mediaRecorder.ondataavailable = (event) => {
        this.audioChunks.push(event.data);
      };

      this.mediaRecorder.onstop = () => {
        const audioBlob = new Blob(this.audioChunks, { type: "audio/webm" });
        this.sendAudioMessage(audioBlob);
        stream.getTracks().forEach((track) => track.stop());
      };

      this.mediaRecorder.start();
      this.isRecording = true;
      this.recordingStartTime = Date.now();

      this.showRecordingIndicator();
      this.startRecordingTimer();

      if (window.navigator && window.navigator.vibrate) {
        window.navigator.vibrate(50);
      }
    } catch (err) {
      console.error("Error accessing microphone:", err);
      alert("Unable to access microphone");
    }
  },

  stopRecording() {
    if (!this.isRecording) return;

    const duration = (Date.now() - this.recordingStartTime) / 1000;

    if (duration < 1) {
      this.cancelRecording();
      alert("Recording too short. Please hold longer.");
      return;
    }

    this.mediaRecorder.stop();
    this.isRecording = false;
    this.hideRecordingIndicator();
    this.stopRecordingTimer();

    if (window.navigator && window.navigator.vibrate) {
      window.navigator.vibrate(50);
    }
  },

  cancelRecording() {
    if (this.mediaRecorder && this.isRecording) {
      this.mediaRecorder.onstop = () => {};
      this.mediaRecorder.stop();
      this.isRecording = false;
      this.hideRecordingIndicator();
      this.stopRecordingTimer();
    }
  },

  showRecordingIndicator() {
    if (this.recordingIndicator) return;

    this.recordingIndicator = document.createElement("div");
    this.recordingIndicator.className = "recording-indicator";
    this.recordingIndicator.style.cssText = `
      position: fixed;
      bottom: 100px;
      left: 50%;
      transform: translateX(-50%);
      background: #ef4444;
      color: white;
      padding: 8px 16px;
      border-radius: 30px;
      font-size: 14px;
      z-index: 1000;
      display: flex;
      align-items: center;
      gap: 8px;
    `;
    this.recordingIndicator.innerHTML = `
      <span class="recording-dot w-2 h-2 bg-white rounded-full animate-pulse"></span>
      <span>Recording... <span class="recording-timer">0s</span></span>
      <span>Release to send</span>
    `;
    document.body.appendChild(this.recordingIndicator);
  },

  hideRecordingIndicator() {
    if (this.recordingIndicator) {
      this.recordingIndicator.remove();
      this.recordingIndicator = null;
    }
  },

  startRecordingTimer() {
    let seconds = 0;
    this.recordingTimer = setInterval(() => {
      seconds++;
      const timerEl =
        this.recordingIndicator?.querySelector(".recording-timer");
      if (timerEl) timerEl.textContent = `${seconds}s`;
    }, 1000);
  },

  stopRecordingTimer() {
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = null;
    }
  },

  sendAudioMessage(blob) {
    const reader = new FileReader();
    reader.onloadend = () => {
      const base64data = reader.result;
      this.pushEventTo(this.el, "send_audio", { audio: base64data });
    };
    reader.readAsDataURL(blob);
  },

  destroyed() {
    if (this.recordingIndicator) {
      this.recordingIndicator.remove();
    }
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
    }
  },
};

export default VoiceRecorder;
