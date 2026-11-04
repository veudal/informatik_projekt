// Import the Firebase Compat SDKs from the CDN
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

// Your specific Firebase web credentials from your firebase_options.dart file
const firebaseConfig = {
  apiKey: 'AIzaSyA0PwzWa4MXpTvI5rI3oxL2mFilrGb5DiM',
  appId: '1:533994402785:web:4c5719057bfcff7ad9d8a0',
  messagingSenderId: '533994402785',
  projectId: 'informatik-projekt-c884e',
  authDomain: 'informatik-projekt-c884e.firebaseapp.com',
  storageBucket: 'informatik-projekt-c884e.firebasestorage.app',
  measurementId: 'G-X5E1E3QS22',
};

// Initialize Firebase in the background service worker
firebase.initializeApp(firebaseConfig);

// Initialize Firebase Messaging
const messaging = firebase.messaging();

// Handle background notifications
messaging.onBackgroundMessage((payload) => {
  console.log("Background message received: ", payload);
});
