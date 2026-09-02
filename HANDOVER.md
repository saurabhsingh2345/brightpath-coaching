# BrightPath Coaching — for the institute

Everything is already running. Nothing to install on a server, no database to
set up.

---

## Open it

### On a laptop or any phone (nothing to install)

**<https://brightpath-coaching.vercel.app>**

Works in Chrome, Safari, Edge — Android *and* iPhone.

### On Android (proper app, home-screen icon)

Download the APK from the latest release:

**<https://github.com/saurabhsingh2345/brightpath-coaching/releases/latest>**

1. Tap **BrightPath-Coaching.apk**.
2. Android will warn that it's not from the Play Store — choose **Install anyway**
   (or allow installs from your browser when prompted). This is normal for an
   app shared directly rather than through the store.
3. Open **BrightPath**.

> On iPhone, use the web link above. Putting an iOS app on a phone requires a
> paid Apple Developer account ($99/yr); the web version is the free path and
> behaves the same. Add it to the home screen from Safari's Share menu and it
> opens full-screen like an app.

---

## Log in

| | Email | Password | What it is |
|---|---|---|---|
| **Your account** | `admin@gmail.com` | `password123` | Yours. Starts empty, ready for real students. |
| Demo admin | `admin@brightpath.edu` | `Admin@123` | Sample institute — see every feature working. |
| Demo student | `aarav@brightpath.edu` | `Student@123` | The same institute seen as a student. |

The login screen has one-tap **Admin** and **Student** buttons for the two demo
accounts, so you can look around without typing anything.

**Please change your password** once you've logged in: **Me → Change password**.
`password123` is only meant to get you in the first time.

---

## Suggested first 15 minutes

1. Tap **Admin** on the login screen. You're now the sample institute with
   10 students, 3 batches, a term of attendance, fees part-collected, exam
   results and chat history.
2. **Home** — the numbers that matter: attendance today, fees pending, overdue.
3. **Attendance** — pick a batch, tap P/A/L/Lv down the list, **Save**. Try
   saving the same day twice; it corrects rather than duplicating.
4. **Fees** → open a student → **Collect** → record a part-payment. A receipt
   is generated immediately.
5. **More → Exams** → open a test → type marks. Totals, percentages, grades and
   ranks calculate as you type. **Publish** to make results visible to students.
6. **Chat** — message a student, or post to a whole batch. The lock icon makes a
   batch group announcement-only.
7. Log out, tap **Student**, and see the same institute from a student's side —
   they can only ever see their own attendance, fees and results.

## Then start for real

1. Log out and sign in as `admin@gmail.com`.
2. **Me → Start fresh** → type `CLEAR DEMO DATA`. This removes the sample
   institute and nothing else. Anything you create yourself can never be
   deleted by this button.
3. **More → Batches** — create your batches (name, course, subject, timing, room).
4. **Students** — add students. Each one automatically gets a login; their
   password starts as `Student@123` and they can change it.
5. **More → Timetable** — build the weekly schedule. It refuses clashes and
   double-booked rooms.
6. **Fees** — open a student and create their installment plan.

---

## Things worth knowing

**Students only see their own records.** This is enforced on the server, not
just hidden in the app. A student cannot reach another student's attendance,
fees or results even deliberately.

**Exam results stay hidden until you publish them.** Enter marks freely; nobody
sees anything until you tap publish.

**Deactivating a student keeps their history.** Use it when someone leaves —
they can no longer log in, but their attendance and fee records remain for your
records. Delete only if you truly want the history gone.

**Attendance can't be duplicated.** One record per student per day, enforced by
the database. Re-marking a day corrects it.

**Chat is monitored by design.** Students can message staff and their own batch
group — never each other privately.

**Study material** takes PDFs and Office documents up to 8 MB each.

---

## If something looks wrong

**"Cannot reach the server"** — the app couldn't reach the internet, or the
server was briefly waking up. Pull down to refresh.

**The web page is blank on first load** — the app is a few megabytes; give it a
moment on a slow connection, then reload.

**Forgotten password** — an admin can reset a student's password by editing the
student. If you lock yourself out of the admin account, contact your developer.

Anything else, send a screenshot to your developer along with roughly what time
it happened.
