importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

// Initialize the Firebase app in the service worker with strict config
firebase.initializeApp({
  apiKey: "AIzaSyAcgXVz5YoUF89cNVIIdhMpGxw7mhCrtrQ",
  authDomain: "smartbez.firebaseapp.com",
  projectId: "smartbez",
  messagingSenderId: "663414398790",
  appId: "1:663414398790:web:7bd3d53dec415a4d180f47"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background message:', payload);
});
