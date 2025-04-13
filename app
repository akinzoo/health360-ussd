// health360-ussd-app/index.js
const express = require("express");
const bodyParser = require("body-parser");
const admin = require("firebase-admin");
const axios = require("axios");
const app = express();

// Middleware
app.use(bodyParser.urlencoded({ extended: false }));

// Initialize Firebase
const serviceAccount = require("./serviceAccountKey.json"); // replace with your service key path
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://<your-database>.firebaseio.com" // replace with your DB URL
});
const db = admin.firestore();

// Africa's Talking Credentials
const AT_USERNAME = "sandbox";
const AT_API_KEY = "your_africastalking_api_key"; // replace with your key
const AT_SMS_URL = "https://api.africastalking.com/version1/messaging";

// Send SMS
async function sendSMS(to, message) {
  try {
    await axios.post(AT_SMS_URL, new URLSearchParams({
      username: AT_USERNAME,
      to,
      message
    }), {
      headers: {
        apikey: AT_API_KEY,
        "Content-Type": "application/x-www-form-urlencoded"
      }
    });
  } catch (error) {
    console.error("SMS Error:", error.response?.data || error.message);
  }
}

// USSD Endpoint
app.post("/ussd", async (req, res) => {
  const { sessionId, phoneNumber, text } = req.body;
  const menu = text.split("*");
  let response = "";

  switch (menu.length) {
    case 1:
      response = `CON Welcome to Health360 Lite\n1. Consult a Doctor\n2. Book a Lab Test\n3. Pharmacy & Prescription\n4. Emergency Services\n5. Health Tips`;
      break;

    case 2:
      switch (menu[0]) {
        case "1":
          response = `CON Choose Consultation Type\n1. General\n2. Specialist\n3. Follow-up`;
          break;
        case "2":
          response = `CON Choose Lab Test\n1. Blood Test\n2. Malaria\n3. COVID-19`;
          break;
        case "3":
          response = `CON Enter Prescription Code or Symptoms:`;
          break;
        case "4":
          await sendSMS(phoneNumber, "🚨 Health360: Emergency request received. Help is on the way.");
          response = `END Emergency alert sent. You'll receive an SMS shortly.`;
          break;
        case "5":
          await sendSMS(phoneNumber, "💡 Health Tip: Drink 8 glasses of water a day for better health.");
          response = `END Health tip sent via SMS.`;
          break;
        default:
          response = `END Invalid choice.`;
      }
      break;

    case 3:
      if (menu[0] === "1") {
        const consultType = ["General", "Specialist", "Follow-up"][parseInt(menu[1]) - 1];
        await db.collection("consultations").add({
          phoneNumber,
          type: consultType,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        await sendSMS(phoneNumber, `🩺 A ${consultType} doctor will call you shortly.`);
        response = `END Your ${consultType} consultation request is confirmed.`;
      } else if (menu[0] === "2") {
        const testType = ["Blood Test", "Malaria", "COVID-19"][parseInt(menu[1]) - 1];
        await db.collection("labRequests").add({
          phoneNumber,
          test: testType,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        await sendSMS(phoneNumber, `🔬 Nearest lab for ${testType}: HealthLab, Main St. Results via SMS.`);
        response = `END ${testType} test booked. Details sent via SMS.`;
      } else if (menu[0] === "3") {
        const prescription = menu[1];
        await db.collection("prescriptions").add({
          phoneNumber,
          prescription,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        await sendSMS(phoneNumber, `💊 Nearest pharmacy: MedPlus, 10 mins away. Use code: RX${Math.floor(Math.random() * 10000)}`);
        response = `END Prescription request received. Pharmacy details sent.`;
      } else {
        response = `END Invalid input.`;
      }
      break;

    default:
      response = `END Invalid input.`;
  }

  res.set("Content-Type", "text/plain");
  res.send(response);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Health360 USSD app running on port ${PORT}`));
