/**
 * BrightPath Coaching - demo data.
 *
 * Idempotent: wipes the domain tables then re-creates a consistent snapshot,
 * so `npm run seed` can be re-run any number of times.
 *
 *   Admin    admin@brightpath.edu / Admin@123
 *   Students <first-name>@brightpath.edu / Student@123
 */
import {
  AnnouncementAudience,
  ConversationType,
  AttendanceStatus,
  FeeStatus,
  PaymentMode,
  PrismaClient,
  Prisma,
  Role,
  Weekday,
} from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import * as dotenv from 'dotenv';
import { buildSamplePdf } from './sample-pdf';

dotenv.config();

const prisma = new PrismaClient();

// The demo/walkthrough admin. Owns all the seeded sample data.
const ADMIN_EMAIL = process.env.SEED_ADMIN_EMAIL ?? 'admin@brightpath.edu';
const ADMIN_PASSWORD = process.env.SEED_ADMIN_PASSWORD ?? 'Admin@123';
const STUDENT_PASSWORD = process.env.SEED_STUDENT_PASSWORD ?? 'Student@123';

// The institute's own admin. Not demo data, so "Clear demo data" keeps it.
const OWNER_EMAIL = process.env.OWNER_ADMIN_EMAIL ?? 'admin@gmail.com';
const OWNER_PASSWORD = process.env.OWNER_ADMIN_PASSWORD ?? 'password123';
const OWNER_NAME = process.env.OWNER_ADMIN_NAME ?? 'Institute Admin';

/**
 * `--if-empty` (used on deploy) seeds only a database that has no users yet,
 * so redeploying never overwrites the institute's real data. Without the flag
 * the demo tables are wiped and rebuilt, which is what you want locally.
 */
const IF_EMPTY = process.argv.includes('--if-empty');

const hash = (p: string) => bcrypt.hash(p, 10);

/** UTC midnight, `daysAgo` days back. Matches the @db.Date columns. */
function dateOnly(daysAgo = 0): Date {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - daysAgo);
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

function daysFromNow(days: number): Date {
  const d = new Date();
  d.setDate(d.getDate() + days);
  d.setHours(12, 0, 0, 0);
  return d;
}

const WEEKDAY_BY_INDEX: Weekday[] = [
  Weekday.SUNDAY,
  Weekday.MONDAY,
  Weekday.TUESDAY,
  Weekday.WEDNESDAY,
  Weekday.THURSDAY,
  Weekday.FRIDAY,
  Weekday.SATURDAY,
];

// Deterministic pseudo-random so re-seeding gives comparable numbers.
let seedState = 42;
function rnd(): number {
  seedState = (seedState * 1103515245 + 12345) % 2147483648;
  return seedState / 2147483648;
}
function pick<T>(arr: T[]): T {
  return arr[Math.floor(rnd() * arr.length)];
}

async function wipe() {
  await prisma.fileObject.deleteMany();
  await prisma.message.deleteMany();
  await prisma.conversationParticipant.deleteMany();
  await prisma.conversation.deleteMany();
  // Order matters only for readability; FKs cascade from users/batches.
  await prisma.feePayment.deleteMany();
  await prisma.fee.deleteMany();
  await prisma.attendance.deleteMany();
  await prisma.examResult.deleteMany();
  await prisma.exam.deleteMany();
  await prisma.studyMaterial.deleteMany();
  await prisma.announcement.deleteMany();
  await prisma.timetableSlot.deleteMany();
  await prisma.student.deleteMany();
  await prisma.batch.deleteMany();
  await prisma.user.deleteMany();
}

async function main() {
  if (IF_EMPTY) {
    const existing = await prisma.user.count();
    if (existing > 0) {
      console.log(
        `\n  Database already has ${existing} user(s) - skipping seed.\n`,
      );
      return;
    }
    console.log('\n  Empty database detected - seeding.\n');
  }

  console.log('\n  BrightPath Coaching - seeding\n');
  await wipe();

  // ── The institute's own admin ───────────────────────────────
  // Created first and never flagged as demo, so it survives a demo wipe.
  const owner = await prisma.user.create({
    data: {
      email: OWNER_EMAIL,
      name: OWNER_NAME,
      role: Role.ADMIN,
      passwordHash: await hash(OWNER_PASSWORD),
    },
  });
  console.log(`  owner      ${owner.email}  (your account, no demo data)`);

  // ── Admin ───────────────────────────────────────────────────
  const admin = await prisma.user.create({
    data: {
      email: ADMIN_EMAIL,
      name: 'Priya Nair',
      role: Role.ADMIN,
      phone: '9800011122',
      passwordHash: await hash(ADMIN_PASSWORD),
      isDemo: true,
    },
  });
  console.log(`  admin      ${admin.email}`);

  // ── Batches ─────────────────────────────────────────────────
  const batchSeed = [
    {
      name: 'JEE Morning A',
      course: 'JEE Main 2027',
      subject: 'Physics, Chemistry, Maths',
      timing: '07:00 AM - 09:30 AM',
      room: 'Room 101',
      capacity: 40,
    },
    {
      name: 'NEET Evening B',
      course: 'NEET 2027',
      subject: 'Physics, Chemistry, Biology',
      timing: '05:00 PM - 07:30 PM',
      room: 'Room 202',
      capacity: 35,
    },
    {
      name: 'Foundation X',
      course: 'Class 10 Foundation',
      subject: 'Science, Maths',
      timing: '04:00 PM - 06:00 PM',
      room: 'Room 103',
      capacity: 30,
    },
  ];

  const batches: Awaited<ReturnType<typeof prisma.batch.create>>[] = [];
  for (const b of batchSeed) {
    batches.push(
      await prisma.batch.create({
        data: { ...b, startDate: daysFromNow(-120), isDemo: true },
      }),
    );
  }
  console.log(`  batches    ${batches.map((b) => b.name).join(', ')}`);

  // ── Students ────────────────────────────────────────────────
  const studentSeed = [
    ['Aarav Sharma', 'aarav', 'Rajesh Sharma', 0, 'JEE Main 2027'],
    ['Diya Patel', 'diya', 'Nilesh Patel', 0, 'JEE Main 2027'],
    ['Vivaan Gupta', 'vivaan', 'Anil Gupta', 0, 'JEE Main 2027'],
    ['Ananya Iyer', 'ananya', 'Suresh Iyer', 0, 'JEE Main 2027'],
    ['Kabir Singh', 'kabir', 'Manjeet Singh', 1, 'NEET 2027'],
    ['Isha Reddy', 'isha', 'Venkat Reddy', 1, 'NEET 2027'],
    ['Rohan Mehta', 'rohan', 'Deepak Mehta', 1, 'NEET 2027'],
    ['Saanvi Joshi', 'saanvi', 'Amit Joshi', 2, 'Class 10 Foundation'],
    ['Arjun Nair', 'arjun', 'Mohan Nair', 2, 'Class 10 Foundation'],
    ['Meera Das', 'meera', 'Sanjay Das', 2, 'Class 10 Foundation'],
  ] as const;

  const students: Awaited<ReturnType<typeof prisma.student.create>>[] = [];
  const studentPasswordHash = await hash(STUDENT_PASSWORD);

  for (let i = 0; i < studentSeed.length; i++) {
    const [name, handle, parentName, batchIdx, course] = studentSeed[i];
    const email = `${handle}@brightpath.edu`;
    const phone = `98${String(11000000 + i * 137711).slice(0, 8)}`;

    const user = await prisma.user.create({
      data: {
        email,
        name,
        role: Role.STUDENT,
        phone,
        passwordHash: studentPasswordHash,
        isDemo: true,
      },
    });

    students.push(
      await prisma.student.create({
        data: {
          userId: user.id,
          studentCode: `BP2026${String(i + 1).padStart(3, '0')}`,
          name,
          phone,
          email,
          parentName,
          parentPhone: `97${String(22000000 + i * 191733).slice(0, 8)}`,
          address: `${12 + i} ${pick(['Lake View', 'MG Road', 'Green Park', 'Rose Villa'])}, Bengaluru 5600${String(10 + i).slice(0, 2)}`,
          course,
          batchId: batches[batchIdx].id,
          admissionDate: daysFromNow(-(100 - i * 6)),
        },
      }),
    );
  }
  console.log(`  students   ${students.length} created (password ${STUDENT_PASSWORD})`);

  // ── Timetable ───────────────────────────────────────────────
  const timetablePlan: Array<{
    batchIdx: number;
    slots: Array<[Weekday, string, string, string, string]>;
  }> = [
    {
      batchIdx: 0,
      slots: [
        [Weekday.MONDAY, '07:00', '08:15', 'Physics', 'Mr. Verma'],
        [Weekday.MONDAY, '08:15', '09:30', 'Maths', 'Ms. Rao'],
        [Weekday.WEDNESDAY, '07:00', '08:15', 'Chemistry', 'Dr. Bose'],
        [Weekday.WEDNESDAY, '08:15', '09:30', 'Physics', 'Mr. Verma'],
        [Weekday.FRIDAY, '07:00', '08:15', 'Maths', 'Ms. Rao'],
        [Weekday.SATURDAY, '07:00', '09:30', 'Mock Test', 'Mr. Verma'],
      ],
    },
    {
      batchIdx: 1,
      slots: [
        [Weekday.TUESDAY, '17:00', '18:15', 'Biology', 'Dr. Menon'],
        [Weekday.TUESDAY, '18:15', '19:30', 'Chemistry', 'Dr. Bose'],
        [Weekday.THURSDAY, '17:00', '18:15', 'Physics', 'Mr. Verma'],
        [Weekday.THURSDAY, '18:15', '19:30', 'Biology', 'Dr. Menon'],
        [Weekday.SATURDAY, '17:00', '19:30', 'Mock Test', 'Dr. Menon'],
      ],
    },
    {
      batchIdx: 2,
      slots: [
        [Weekday.MONDAY, '16:00', '17:00', 'Science', 'Ms. Kaur'],
        [Weekday.WEDNESDAY, '16:00', '17:00', 'Maths', 'Ms. Rao'],
        [Weekday.FRIDAY, '16:00', '18:00', 'Science', 'Ms. Kaur'],
      ],
    },
  ];

  let slotCount = 0;
  for (const plan of timetablePlan) {
    const batch = batches[plan.batchIdx];
    for (const [weekday, startTime, endTime, subject, teacher] of plan.slots) {
      await prisma.timetableSlot.create({
        data: {
          batchId: batch.id,
          weekday,
          startTime,
          endTime,
          subject,
          teacher,
          room: batch.room,
        },
      });
      slotCount++;
    }
  }
  console.log(`  timetable  ${slotCount} slots`);

  // ── Attendance: last 30 days, only on days the batch actually meets ──
  const meetingDays = new Map<string, Set<Weekday>>();
  for (const plan of timetablePlan) {
    meetingDays.set(
      batches[plan.batchIdx].id,
      new Set(plan.slots.map((s) => s[0])),
    );
  }

  const attendanceRows: Prisma.AttendanceCreateManyInput[] = [];
  for (let daysAgo = 30; daysAgo >= 0; daysAgo--) {
    const date = dateOnly(daysAgo);
    const weekday = WEEKDAY_BY_INDEX[date.getUTCDay()];

    for (const student of students) {
      if (!student.batchId) continue;
      if (!meetingDays.get(student.batchId)?.has(weekday)) continue;

      const roll = rnd();
      let status: AttendanceStatus;
      if (roll < 0.82) status = AttendanceStatus.PRESENT;
      else if (roll < 0.9) status = AttendanceStatus.LATE;
      else if (roll < 0.96) status = AttendanceStatus.ABSENT;
      else status = AttendanceStatus.LEAVE;

      attendanceRows.push({
        studentId: student.id,
        batchId: student.batchId,
        date,
        status,
        remarks:
          status === AttendanceStatus.LEAVE
            ? pick(['Medical leave', 'Family function', 'Approved leave'])
            : status === AttendanceStatus.LATE
              ? 'Arrived late'
              : null,
        markedById: admin.id,
      });
    }
  }
  await prisma.attendance.createMany({ data: attendanceRows });
  console.log(`  attendance ${attendanceRows.length} records over 31 days`);

  // ── Fees: 3 installments each, with realistic payment progress ──
  let feeCount = 0;
  let paymentCount = 0;
  let receiptSeq = 1;
  const year = new Date().getFullYear();

  for (let i = 0; i < students.length; i++) {
    const student = students[i];
    const totalFee = student.course.includes('Foundation') ? 30000 : 60000;
    const per = totalFee / 3;

    const plan = [
      { title: 'Term 1', dueDate: daysFromNow(-60) },
      { title: 'Term 2', dueDate: daysFromNow(-5) },
      { title: 'Term 3', dueDate: daysFromNow(45) },
    ];

    for (let n = 0; n < plan.length; n++) {
      const fee = await prisma.fee.create({
        data: {
          studentId: student.id,
          title: plan[n].title,
          totalAmount: new Prisma.Decimal(per),
          dueDate: plan[n].dueDate,
          installmentNo: n + 1,
          totalInstallments: 3,
          status: FeeStatus.PENDING,
        },
      });
      feeCount++;

      // Term 1 paid in full for nearly everyone; Term 2 mixed; Term 3 open.
      let payAmount = 0;
      if (n === 0) payAmount = i === 9 ? per / 2 : per;
      else if (n === 1) {
        if (i % 3 === 0) payAmount = per;
        else if (i % 3 === 1) payAmount = per / 2;
      }

      if (payAmount > 0) {
        await prisma.feePayment.create({
          data: {
            feeId: fee.id,
            amount: new Prisma.Decimal(payAmount),
            mode: pick([
              PaymentMode.UPI,
              PaymentMode.CASH,
              PaymentMode.CARD,
              PaymentMode.BANK_TRANSFER,
            ]),
            reference: `TXN${String(100000 + i * 733 + n).slice(0, 6)}`,
            paidAt: new Date(plan[n].dueDate.getTime() - 2 * 86400000),
            receiptNo: `BP-R${year}-${String(receiptSeq++).padStart(4, '0')}`,
            recordedById: admin.id,
          },
        });
        paymentCount++;
      }

      const overdue = plan[n].dueDate.getTime() < Date.now();
      const status =
        payAmount >= per
          ? FeeStatus.PAID
          : overdue
            ? FeeStatus.OVERDUE
            : payAmount > 0
              ? FeeStatus.PARTIAL
              : FeeStatus.PENDING;

      await prisma.fee.update({
        where: { id: fee.id },
        data: { paidAmount: new Prisma.Decimal(payAmount), status },
      });
    }
  }
  console.log(`  fees       ${feeCount} installments, ${paymentCount} payments`);

  // ── Exams + results ─────────────────────────────────────────
  const examPlan = [
    {
      batchIdx: 0,
      name: 'Monthly Test - August',
      daysAgo: 20,
      subjects: [
        { name: 'Physics', maxMarks: 100 },
        { name: 'Chemistry', maxMarks: 100 },
        { name: 'Maths', maxMarks: 100 },
      ],
      published: true,
    },
    {
      batchIdx: 1,
      name: 'NEET Mock 1',
      daysAgo: 12,
      subjects: [
        { name: 'Physics', maxMarks: 90 },
        { name: 'Chemistry', maxMarks: 90 },
        { name: 'Biology', maxMarks: 180 },
      ],
      published: true,
    },
    {
      batchIdx: 2,
      name: 'Foundation Unit Test 2',
      daysAgo: 8,
      subjects: [
        { name: 'Science', maxMarks: 50 },
        { name: 'Maths', maxMarks: 50 },
      ],
      published: true,
    },
    {
      batchIdx: 0,
      name: 'Monthly Test - September',
      daysAgo: -14, // upcoming
      subjects: [
        { name: 'Physics', maxMarks: 100 },
        { name: 'Chemistry', maxMarks: 100 },
        { name: 'Maths', maxMarks: 100 },
      ],
      published: false,
    },
  ];

  const gradeFor = (pct: number) =>
    pct >= 90 ? 'A+' : pct >= 80 ? 'A' : pct >= 70 ? 'B+' : pct >= 60 ? 'B' : pct >= 50 ? 'C' : pct >= 40 ? 'D' : 'F';

  let examCount = 0;
  let resultCount = 0;

  for (const plan of examPlan) {
    const batch = batches[plan.batchIdx];
    const totalMarks = plan.subjects.reduce((s, x) => s + x.maxMarks, 0);

    const exam = await prisma.exam.create({
      data: {
        batchId: batch.id,
        name: plan.name,
        examDate: daysFromNow(-plan.daysAgo),
        description: `${plan.name} for ${batch.name}`,
        subjects: plan.subjects as unknown as Prisma.InputJsonValue,
        totalMarks,
        isPublished: plan.published,
      },
    });
    examCount++;
    if (!plan.published) continue;

    const batchStudents = students.filter((s) => s.batchId === batch.id);
    const scored: Array<{ id: string; obtained: number; pct: number; marks: any }> = [];

    for (const student of batchStudents) {
      const marks = plan.subjects.map((sub) => {
        const ratio = 0.45 + rnd() * 0.5; // 45% - 95%
        return {
          subject: sub.name,
          marksObtained: Math.round(sub.maxMarks * ratio),
          maxMarks: sub.maxMarks,
        };
      });
      const obtained = marks.reduce((s, m) => s + m.marksObtained, 0);
      const pct = Number(((obtained / totalMarks) * 100).toFixed(2));
      scored.push({ id: student.id, obtained, pct, marks });
    }

    scored.sort((a, b) => b.pct - a.pct);

    for (let i = 0; i < scored.length; i++) {
      const s = scored[i];
      const rank =
        i > 0 && scored[i - 1].pct === s.pct
          ? // ties share a rank
            (await prisma.examResult.findFirst({
              where: { examId: exam.id, studentId: scored[i - 1].id },
              select: { rank: true },
            }))?.rank ?? i + 1
          : i + 1;

      await prisma.examResult.create({
        data: {
          examId: exam.id,
          studentId: s.id,
          marks: s.marks as unknown as Prisma.InputJsonValue,
          totalMarks,
          obtained: new Prisma.Decimal(s.obtained),
          percentage: new Prisma.Decimal(s.pct),
          grade: gradeFor(s.pct),
          rank,
          remarks:
            s.pct >= 80
              ? 'Excellent work'
              : s.pct >= 60
                ? 'Good, keep it up'
                : 'Needs more practice',
        },
      });
      resultCount++;
    }
  }
  console.log(`  exams      ${examCount} exams, ${resultCount} results`);

  // ── Study material: real, downloadable sample PDFs ──────────
  const materialSeed = [
    [
      'Rotational Motion - Class Notes',
      'Physics',
      0,
      [
        'Moment of inertia depends on both mass and how that mass is',
        'distributed about the axis of rotation.',
        '',
        'I = sum of m*r^2 for every particle in the body.',
        'Torque = I * angular acceleration.',
        'Angular momentum L = I * omega, conserved with no external torque.',
        '',
        'Worked example: a solid disc rolling without slipping down an',
        'incline reaches the bottom slower than a sliding block, because',
        'part of its potential energy becomes rotational kinetic energy.',
      ],
    ],
    [
      'Organic Chemistry Reaction Map',
      'Chemistry',
      0,
      [
        'Alkane  --halogenation-->  Haloalkane',
        'Haloalkane  --aqueous KOH-->  Alcohol',
        'Alcohol  --conc. H2SO4, heat-->  Alkene',
        'Alkene  --Markovnikov addition-->  Haloalkane',
        'Alcohol  --oxidation-->  Aldehyde  --oxidation-->  Acid',
        '',
        'Remember: primary alcohols oxidise all the way to acids,',
        'secondary alcohols stop at ketones, tertiary resist oxidation.',
      ],
    ],
    [
      'Calculus Practice Set 4',
      'Maths',
      0,
      [
        '1.  Differentiate  y = x^3 * ln(x)',
        '2.  Evaluate  the integral of x*e^x dx',
        '3.  Find the maxima of  f(x) = x^3 - 6x^2 + 9x + 2',
        '4.  Evaluate  limit as x->0 of  sin(3x)/x',
        '5.  Area between  y = x^2  and  y = 2x',
        '',
        'Attempt without notes first, then check your working.',
      ],
    ],
    [
      'Human Physiology Summary',
      'Biology',
      1,
      [
        'Circulation: right heart to lungs, left heart to the body.',
        'Gas exchange happens across the alveolar membrane by diffusion.',
        '',
        'Nephron: glomerulus filters, tubules reabsorb what the body needs,',
        'collecting duct fine-tunes water under ADH.',
        '',
        'Neuron: resting potential -70mV, threshold around -55mV,',
        'sodium in to depolarise, potassium out to repolarise.',
      ],
    ],
    [
      'NEET Chemistry Formula Sheet',
      'Chemistry',
      1,
      [
        'PV = nRT                     ideal gas',
        'pH = -log[H+]                acidity',
        'dG = dH - T*dS               spontaneity',
        'rate = k[A]^m[B]^n           rate law',
        'N = N0 * e^(-kt)             first order decay',
        '',
        'Carry units through every calculation - most lost marks are',
        'unit errors, not concept errors.',
      ],
    ],
    [
      'Class 10 Science Revision',
      'Science',
      2,
      [
        'Light: real images form on the far side of a converging lens.',
        'Use the sign convention consistently: 1/v - 1/u = 1/f.',
        '',
        'Electricity: V = IR, power P = VI, series adds resistance,',
        'parallel adds conductance.',
        '',
        'Life processes: photosynthesis stores energy, respiration',
        'releases it.',
      ],
    ],
    [
      'Institute Handbook 2026',
      'General',
      null,
      [
        'Timings are on your timetable in this app. Please arrive five',
        'minutes early.',
        '',
        'Attendance below 75% is reviewed with parents.',
        'Fees are payable by the due date shown under Fees; receipts are',
        'issued in the app immediately.',
        '',
        'Use Chat for doubts between classes. Be respectful - staff can',
        'see every message.',
      ],
    ],
  ] as const;

  for (const [title, subject, batchIdx, lines] of materialSeed) {
    const pdf = buildSamplePdf(title, [...lines]);
    const stored = await prisma.fileObject.create({
      data: {
        fileName: `${title.toLowerCase().replace(/[^a-z0-9]+/g, '-')}.pdf`,
        mimeType: 'application/pdf',
        size: pdf.length,
        data: new Uint8Array(pdf),
        isDemo: true,
      },
    });

    await prisma.studyMaterial.create({
      data: {
        title,
        description: `Reference material for ${subject}.`,
        subject,
        batchId: batchIdx === null ? null : batches[batchIdx].id,
        fileName: stored.fileName,
        fileUrl: `${(process.env.PUBLIC_BASE_URL ?? 'http://localhost:4000').replace(/\/$/, '')}/api/files/${stored.id}`,
        fileType: 'application/pdf',
        fileSize: pdf.length,
        isDemo: true,
        uploadedById: admin.id,
      },
    });
  }

  console.log(`  materials  ${materialSeed.length} documents`);

  // ── Announcements ───────────────────────────────────────────
  const annSeed = [
    {
      title: 'Fee reminder: Term 2',
      body: 'Term 2 fees were due last week. Please clear pending balances at the front desk or via UPI. Receipts are available in the app under Fees.',
      audience: AnnouncementAudience.ALL,
      batchIdx: null,
      isPinned: true,
      daysAgo: 1,
    },
    {
      title: 'Monthly Test - September scheduled',
      body: 'The next monthly test is in two weeks. Syllabus covers Rotational Motion, Thermodynamics and Integral Calculus.',
      audience: AnnouncementAudience.BATCH,
      batchIdx: 0,
      isPinned: false,
      daysAgo: 2,
    },
    {
      title: 'NEET Mock 2 on Saturday',
      body: 'Report by 4:45 PM in Room 202. Bring your own OMR pencils. Duration 3 hours.',
      audience: AnnouncementAudience.BATCH,
      batchIdx: 1,
      isPinned: false,
      daysAgo: 3,
    },
    {
      title: 'Institute closed on Friday',
      body: 'BrightPath will remain closed this Friday for a public holiday. Friday classes are shifted to Saturday morning.',
      audience: AnnouncementAudience.ALL,
      batchIdx: null,
      isPinned: false,
      daysAgo: 5,
    },
    {
      title: 'New study material uploaded',
      body: 'Class 10 Science revision notes are now available in the Study Material section.',
      audience: AnnouncementAudience.BATCH,
      batchIdx: 2,
      isPinned: false,
      daysAgo: 7,
    },
  ];

  for (const a of annSeed) {
    await prisma.announcement.create({
      data: {
        title: a.title,
        body: a.body,
        audience: a.audience,
        batchId: a.batchIdx === null ? null : batches[a.batchIdx].id,
        isPinned: a.isPinned,
        isDemo: true,
        authorId: admin.id,
        createdAt: daysFromNow(-a.daysAgo),
      },
    });
  }
  console.log(`  announce   ${annSeed.length} announcements`);

  // ── Chat: one batch thread per batch + a few 1:1 threads ──
  const directKey = (a: string, b: string) => [a, b].sort().join(':');
  let threadCount = 0;
  let messageCount = 0;

  const say = async (
    conversationId: string,
    senderId: string,
    body: string,
    minutesAgo: number,
  ) => {
    const at = new Date(Date.now() - minutesAgo * 60000);
    await prisma.message.create({
      data: { conversationId, senderId, body, createdAt: at },
    });
    await prisma.conversation.update({
      where: { id: conversationId },
      data: {
        lastMessageAt: at,
        lastMessageText: body.length > 120 ? `${body.slice(0, 117)}…` : body,
      },
    });
    messageCount++;
  };

  for (const batch of batches) {
    const members = students.filter((s) => s.batchId === batch.id);
    const conversation = await prisma.conversation.create({
      data: {
        type: ConversationType.BATCH,
        batchId: batch.id,
        title: batch.name,
        participants: {
          create: [
            { userId: admin.id },
            ...members.map((m) => ({ userId: m.userId })),
          ],
        },
      },
    });
    threadCount++;

    await say(
      conversation.id,
      admin.id,
      `Welcome to the ${batch.name} group. Ask your doubts here and please keep it on topic.`,
      600,
    );
    if (members.length > 0) {
      await say(
        conversation.id,
        members[0].userId,
        'Thank you sir. Will the mock test syllabus be shared here?',
        540,
      );
      await say(
        conversation.id,
        admin.id,
        'Yes, I will post the syllabus and the notes in Study Material by tomorrow.',
        520,
      );
    }
    if (members.length > 1) {
      await say(
        conversation.id,
        members[1].userId,
        'Noted, thank you!',
        480,
      );
    }
  }

  // 1:1 threads for the first three students
  const dmSeed: Array<[number, Array<[boolean, string, number]>]> = [
    [
      0,
      [
        [false, 'Sir, I could not follow the rotational motion problem from today.', 300],
        [true, 'No problem Aarav. Stay back 15 minutes tomorrow and we will redo it on the board.', 280],
        [false, 'Thank you sir, I will be there.', 275],
      ],
    ],
    [
      4,
      [
        [false, 'Sir, I will be on medical leave on Thursday.', 180],
        [true, 'Thanks for letting me know. I have marked it as approved leave.', 170],
      ],
    ],
    [
      9,
      [
        [false, 'Sir, my Term 1 balance is still showing. I paid half last week.', 90],
        [true, 'Checked — the ₹5,000 partial payment is recorded. The remaining ₹5,000 is still open.', 80],
      ],
    ],
  ];

  for (const [idx, script] of dmSeed) {
    const student = students[idx];
    const conversation = await prisma.conversation.create({
      data: {
        type: ConversationType.DIRECT,
        directKey: directKey(admin.id, student.userId),
        participants: {
          create: [{ userId: admin.id }, { userId: student.userId }],
        },
      },
    });
    threadCount++;
    for (const [fromAdmin, body, minutesAgo] of script) {
      await say(
        conversation.id,
        fromAdmin ? admin.id : student.userId,
        body,
        minutesAgo,
      );
    }
  }

  // Admin has read everything they sent; students have unread replies.
  await prisma.conversationParticipant.updateMany({
    where: { userId: admin.id },
    data: { lastReadAt: new Date() },
  });

  console.log(`  chat       ${threadCount} threads, ${messageCount} messages`);

  console.log('\n  Logins');
  console.log('  ─────────────────────────────────────────────────────────');
  console.log(`  YOUR ADMIN   ${OWNER_EMAIL} / ${OWNER_PASSWORD}`);
  console.log('               Starts clean. Use "Clear demo data" in');
  console.log('               Profile once you have finished the walkthrough.');
  console.log('');
  console.log(`  DEMO ADMIN   ${ADMIN_EMAIL} / ${ADMIN_PASSWORD}`);
  console.log(`  DEMO STUDENT aarav@brightpath.edu / ${STUDENT_PASSWORD}`);
  console.log('               (all 10 demo students share that password)\n');
}

main()
  .catch((e) => {
    console.error('\n  Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
