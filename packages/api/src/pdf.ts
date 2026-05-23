import PDFDocument from 'pdfkit';

export type AuthDocInput = {
  order: {
    id: string;
    order_code: string;
    source_tracking_id: string | null;
    user_signature_url: string | null;
    user_id_proof_url: string | null;
    created_at: string;
  };
  user: { full_name: string | null; phone: string };
  deliveryAddress: string | null;
  sourceCourierName: string | null;
  sourceBranchName: string | null;
  agent: {
    full_name: string;
    phone: string;
    vehicle_type: string | null;
    vehicle_number: string | null;
  } | null;
};

async function fetchImage(url: string | null): Promise<Buffer | null> {
  if (!url) return null;
  try {
    if (url.startsWith('data:')) {
      const m = url.match(/^data:image\/[a-zA-Z0-9.+-]+;base64,(.+)$/);
      return m ? Buffer.from(m[1], 'base64') : null;
    }
    const res = await fetch(url);
    if (!res.ok) return null;
    return Buffer.from(await res.arrayBuffer());
  } catch {
    return null;
  }
}

export async function buildAuthorizationPdf(input: AuthDocInput): Promise<Buffer> {
  const [signatureImg, idImg] = await Promise.all([
    fetchImage(input.order.user_signature_url),
    fetchImage(input.order.user_id_proof_url),
  ]);

  const doc = new PDFDocument({ size: 'A4', margin: 50 });
  const chunks: Buffer[] = [];
  doc.on('data', (c) => chunks.push(c));
  const finished = new Promise<void>((resolve) => doc.on('end', () => resolve()));

  const today = new Date().toLocaleDateString('en-IN', {
    year: 'numeric', month: 'long', day: 'numeric',
  });

  doc.fontSize(10).fillColor('#666').text('Parsalo — Thrissur', 50, 50);
  doc.text(today, 50, 50, { align: 'right' });

  doc.moveDown(2);
  doc.fontSize(18).fillColor('#000').text('Parcel Collection Authorization', { align: 'center' });
  doc.fontSize(10).fillColor('#666').text(`Order ${input.order.order_code}`, { align: 'center' });
  doc.moveDown(1.5);

  doc.fontSize(11).fillColor('#000').text(
    'I, the undersigned, hereby authorize Parsalo Pvt. Ltd. and its designated delivery agent ' +
    'to collect the parcel described below from the courier office on my behalf, and to deliver it ' +
    'to the address specified.',
    { align: 'justify' },
  );

  section(doc, 'CUSTOMER', [
    ['Name', input.user.full_name ?? '—'],
    ['Phone', input.user.phone],
    ['Delivery address', input.deliveryAddress ?? '—'],
  ]);

  section(doc, 'PARCEL', [
    ['Courier', input.sourceCourierName ?? '—'],
    ['Tracking ID', input.order.source_tracking_id ?? '—'],
    ['Branch', input.sourceBranchName ?? '—'],
  ]);

  if (input.agent) {
    section(doc, 'AUTHORIZED AGENT', [
      ['Name', input.agent.full_name],
      ['Phone', input.agent.phone],
      ['Vehicle', [input.agent.vehicle_type, input.agent.vehicle_number].filter(Boolean).join(' · ') || '—'],
    ]);
  }

  doc.moveDown(1);
  doc.fontSize(9).fillColor('#444').text(
    'Declaration: I confirm the parcel described above belongs to me and that I take full ' +
    'responsibility for any claims arising from this collection. I have provided a copy of my ' +
    'government-issued ID for verification by the courier office.',
    { align: 'justify' },
  );

  const colWidth = 220;
  const col1X = 50;
  const col2X = doc.page.width - colWidth - 50;
  const colY = doc.y + 20;

  if (signatureImg) {
    try { doc.image(signatureImg, col1X, colY, { fit: [colWidth, 80] }); } catch { /* ignore */ }
  }
  if (idImg) {
    try { doc.image(idImg, col2X, colY, { fit: [colWidth, 80] }); } catch { /* ignore */ }
  }

  const lineY = colY + 90;
  doc.moveTo(col1X, lineY).lineTo(col1X + colWidth, lineY).stroke();
  doc.moveTo(col2X, lineY).lineTo(col2X + colWidth, lineY).stroke();

  doc.fontSize(9).fillColor('#666');
  doc.text('Customer signature', col1X, lineY + 5, { width: colWidth });
  doc.text('Government-issued ID', col2X, lineY + 5, { width: colWidth });

  doc.fontSize(8).fillColor('#999').text(
    `Issued by Parsalo · ${new Date(input.order.created_at).toLocaleString('en-IN')} · ID ${input.order.id}`,
    50, doc.page.height - 60,
    { align: 'center', width: doc.page.width - 100 },
  );

  doc.end();
  await finished;
  return Buffer.concat(chunks);
}

function section(doc: PDFKit.PDFDocument, title: string, rows: [string, string][]) {
  doc.moveDown(0.8);
  doc.fontSize(9).fillColor('#888').text(title);
  doc.moveDown(0.2);
  doc.fontSize(11).fillColor('#000');
  for (const [k, v] of rows) {
    doc.text(`${k}: `, { continued: true }).fillColor('#000').text(v);
    doc.fillColor('#000');
  }
}
