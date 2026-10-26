/**
 * RoastGuard — Interactive Landing Page Script
 * Powers the Live Gemma 4 Roast Simulator and micro-interactions
 */

document.addEventListener('DOMContentLoaded', () => {
  // Simulator Elements
  const appSelect = document.getElementById('simApp');
  const slider = document.getElementById('simThreshold');
  const thresholdVal = document.getElementById('simThresholdVal');
  const triggerBtn = document.getElementById('triggerRoastBtn');
  const roastOutput = document.getElementById('simRoastOutput');
  const intensityButtons = document.querySelectorAll('.btn-intensity');
  const soundToggle = document.getElementById('soundToggle');

  let currentIntensity = 'savage';
  let isSoundEnabled = true;

  // App-specific and Intensity-specific Roast Database
  const roasts = {
    instagram: {
      mild: [
        "Hey, you've been on Instagram for {min} minutes. Maybe check your real life notifications instead?",
        "Your explore feed will still be full of recycled memes tomorrow. Take a break.",
        "You've scrolled past 40 influencer vacations in {min} minutes. Time to look up."
      ],
      savage: [
        "{min} minutes watching other people live interesting lives while you lay like a pretzel in bed. Close the app.",
        "Another {min} minutes donated to Meta's ad revenue. You aren't relaxing; you're just procrastinating your potential.",
        "Your thumb has run a marathon in {min} minutes, but your to-do list hasn't moved an inch."
      ],
      nuclear: [
        "{min} MINUTES of dopamine sludge?! Put the phone face down, drink water, and reflect on why you're ignoring your real goals.",
        "Emergency intervention: You've wasted {min} minutes watching 7-second clips of people who don't know you exist. GO TO SLEEP.",
        "Your future self is screaming right now. Close Instagram immediately or face total regret tomorrow morning."
      ]
    },
    tiktok: {
      mild: [
        "That's {min} minutes of TikTok dances. Your brain might appreciate some fresh air.",
        "The algorithm won this round. Step away before the next 15-second loop.",
        "Time flies when your attention span is 3 seconds. {min} minutes passed!"
      ],
      savage: [
        "{min} minutes on TikTok. At this rate, your attention span is shorter than a goldfish's memory. Lock it.",
        "You came on for one recipe and you've been watching conspiracy theories for {min} minutes. Close it.",
        "The sound effects in your head must be deafening after {min} minutes of this nonsense. Put it down."
      ],
      nuclear: [
        "ATTENTION SPAN CRITICAL: {min} minutes absorbed by the infinite feed! Close TikTok before your brain turns into mush.",
        "You've watched 180 meaningless videos in {min} minutes. Stop letting a server in Oregon dictate your evening.",
        "Nuclear alert: You have zero willpower right now. That's why I'm here. Close the app immediately."
      ]
    },
    youtube: {
      mild: [
        "{min} minutes of YouTube Shorts. Remember when videos had beginnings and endings?",
        "You've watched 35 shorts in {min} minutes. Time to stretch your neck.",
        "Shorts limit exceeded. You've been here for {min} minutes."
      ],
      savage: [
        "{min} minutes watching podcast clips of millionaires telling you to wake up at 4 AM while you scroll in bed at midnight.",
        "You've spent {min} minutes learning how to forge a sword you will never build. Close YouTube.",
        "Another {min} minutes lost to satisfying soap-cutting videos. Your laundry is still waiting."
      ],
      nuclear: [
        "CRITICAL DOOMSCROLL DETECTED: {min} minutes of Shorts. You are trapped in the algorithm's tractor beam. DISCONNECT NOW.",
        "You have officially wasted {min} minutes of your one precious life on clip compilations. Shut it down.",
        "Intervention level: Nuclear. YouTube Shorts is stealing your hours. Lock your phone."
      ]
    },
    reddit: {
      mild: [
        "{min} minutes reading internet arguments. Nobody ever won a Reddit argument; time to log off.",
        "You've browsed 15 subreddits in {min} minutes. How about closing the browser?",
        "Reddit break needed. {min} minutes elapsed."
      ],
      savage: [
        "You've spent {min} minutes reading unsolicited life advice from anonymous 14-year-olds. Close Reddit.",
        "{min} minutes in the comment section doomscrolling drama between strangers. Get a hobby.",
        "You've downvoted three opinions and solved zero problems in {min} minutes. Put the phone down."
      ],
      nuclear: [
        "REDDIT RABBIT HOLE LOCK: {min} minutes reading threads about topics you didn't care about an hour ago. Close it now.",
        "You're {min} minutes deep into an AITA thread about a wedding you didn't attend. GO TOUCH GRASS.",
        "Warning: Terminal cynicism detected after {min} minutes on Reddit. Shut the screen."
      ]
    },
    twitter: {
      mild: [
        "{min} minutes on Twitter/X. Your blood pressure has probably spiked; time for a break.",
        "Too many hot takes in {min} minutes. Step away.",
        "Take a breath and close the timeline. {min} minutes passed."
      ],
      savage: [
        "{min} minutes scrolling rage-bait designed to keep you angry and clicking. Stop playing their game.",
        "You've spent {min} minutes reading tech influencers argue about JavaScript frameworks. Go write some actual code.",
        "Nobody's tweet was worth {min} minutes of your time tonight. Put the phone face down."
      ],
      nuclear: [
        "DOOMSCROLL SHUTDOWN: {min} minutes of pure timeline toxicity. Close X immediately and protect your sanity.",
        "You've consumed {min} minutes of catastrophic headlines. The world is fine; your sleep schedule is not. DISMISS.",
        "Nuclear alert: You are arguing with bots in your head after {min} minutes of scrolling. Shut it down."
      ]
    }
  };

  // Threshold Slider Live Update
  if (slider && thresholdVal) {
    slider.addEventListener('input', (e) => {
      thresholdVal.textContent = `${e.target.value} min`;
    });
  }

  // Intensity Switcher
  intensityButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      intensityButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      currentIntensity = btn.dataset.level;
    });
  });

  // Sound Synthesizer via Web Audio API (No external assets required!)
  function playAlertBeep() {
    if (!isSoundEnabled) return;
    try {
      const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();

      osc.type = currentIntensity === 'nuclear' ? 'sawtooth' : 'sine';
      osc.frequency.setValueAtTime(currentIntensity === 'nuclear' ? 440 : 587.33, audioCtx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(880, audioCtx.currentTime + 0.2);

      gain.gain.setValueAtTime(0.15, audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.35);

      osc.connect(gain);
      gain.connect(audioCtx.destination);

      osc.start();
      osc.stop(audioCtx.currentTime + 0.35);
    } catch (e) {
      // Audio autoplay policy fallback
    }
  }

  // Trigger Roast Action
  function triggerRoast() {
    const app = appSelect ? appSelect.value : 'instagram';
    const minutes = slider ? slider.value : '45';
    const intensity = currentIntensity || 'savage';

    const pool = (roasts[app] && roasts[app][intensity]) || roasts.instagram.savage;
    const randomRoast = pool[Math.floor(Math.random() * pool.length)].replace('{min}', minutes);

    playAlertBeep();

    // Typewriter / Streaming Effect
    if (roastOutput) {
      roastOutput.textContent = '';
      let index = 0;
      triggerBtn.disabled = true;
      triggerBtn.style.opacity = '0.7';

      const interval = setInterval(() => {
        if (index < randomRoast.length) {
          roastOutput.textContent += randomRoast[index];
          index++;
        } else {
          clearInterval(interval);
          triggerBtn.disabled = false;
          triggerBtn.style.opacity = '1';
        }
      }, 18);
    }
  }

  if (triggerBtn) {
    triggerBtn.addEventListener('click', triggerRoast);
  }

  // Audio Toggle
  if (soundToggle) {
    soundToggle.addEventListener('click', () => {
      isSoundEnabled = !isSoundEnabled;
      soundToggle.classList.toggle('muted', !isSoundEnabled);
      soundToggle.title = isSoundEnabled ? 'Sound Enabled' : 'Sound Muted';
    });
  }

  // Initial trigger so the simulator starts populated
  triggerRoast();
});
