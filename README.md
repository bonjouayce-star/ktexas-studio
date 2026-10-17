# KTEXAS Studio

A cinematic, responsive music and video studio website with bookings, a private admin dashboard and a private client workspace. Built with Vite, vanilla JavaScript and Supabase, with server endpoints prepared for Vercel.

## Run locally

Use Node.js 22.12+ and run `npm install`, then `npm run dev`. Build with `npm run build`; run checks with `npm test`. The local development server runs the API endpoints too.

- Website: `/`
- Studio dashboard: `/admin` (no public navigation link)
- Client workspace: `/portal`

Without account configuration, clearly marked local demos are available. Sample admin/client changes persist in this browser session only. Reset demo data in the admin dashboard to restore the examples. Public booking demonstrations do not save or send visitor information.

## Included

- Cinematic concept reel with playback controls; replace it with a real video or YouTube URL in Studio experience.
- An original, loudness-matched before/after instrumental audio comparison with playback and seeking.
- Editable illustrative session packages that prefill the booking form.
- Editable producer/engineer profiles, currently labelled placeholders.
- Booking management, staff notes, calendar, CSV export, portfolio, services, social links and studio settings.
- Client invitations, progress updates, private file delivery and audio previews, feedback and studio replies.
- Server-validated deposit quotes and Stripe-hosted checkout; payment is recorded only after a verified payment webhook.
- Booking receipt and confirmation emails, day-before reminders, deposit receipts and a retryable email queue using Resend.

## Connect Supabase

1. Create your dedicated studio project. Run `database/setup.sql`, then `database/experience.sql`, then `database/workflow.sql`, then `database/launch.sql` in the SQL editor.
2. Create your owner account in Authentication > Users. Add its UUID to `studio_admins` as shown in setup.sql. Disable public signups; clients are invited through the dashboard.
3. Copy `.env.example` to `.env`. Set the two public `VITE_SUPABASE_*` values and the protected server `SUPABASE_URL` and `SUPABASE_SECRET_KEY` values. Never prefix server secrets with `VITE_`, commit them, or paste them into chat.
4. Set `SITE_URL` to the exact website origin. Configure Supabase Auth Site URL and allowed redirects for `/portal?mode=invite` and `/portal?mode=recovery`, and `/portal?mode=invite&staff=1`, including localhost while developing. Configure Auth email delivery for invitations and password recovery separately from Resend booking messages.
5. Restart local development after changing environment values. On Vercel, set the same environment values and rebuild when public values change.

Client records are scoped to the signed-in client, owner, manager or assigned creative staff. Files use a private storage bucket and short-lived download URLs. The hidden admin URL is a convenience; access protection comes from authentication, explicit staff membership and database policies. Live database policies still need verification against your new project.

## Studio tour, availability and client approvals

Studio experience > Studio tour controls room photos, descriptions, capabilities, equipment lists and an optional externally hosted 360° tour. Default photography and equipment are explicitly marked reference placeholders.

The public availability calendar uses one studio space, Monday–Saturday 10:00–22:00 EAT, and shows starts compatible with the entire selected duration. Staff manage blocked periods under Availability; confirmed sessions reserve their full interval. PostgreSQL exclusion constraints reject overlapping blocks and confirmed sessions, including competing confirmations. Pending enquiries do not reserve time. Cancelling a confirmed booking releases its reservation. Existing overlapping confirmed bookings cause workflow.sql to fail intentionally; resolve them before applying it. The fixed opening hours are defined in lib/scheduling.js.

Clients use Prepare to save a structured brief and privately upload references. Staff review these in Client projects. Approvals records approval of a specific final file version; revisions are tracked as open, in progress or resolved. New file versions need their own approval. This records creative acceptance, not payment authorization or a substitute for your client contract.

Projects supports artist/client names, release years and credits. Testimonials supports real quotes and drafts; publishing requires recorded client permission. No client quotes have been fabricated. Actual names, released work, photos and licensed media must be supplied by the studio.

## M-Pesa

A Safaricom Daraja integration is prepared alongside Stripe, with an explicitly separate local demonstration that never sends a phone prompt or changes the actual project deposit. Configure the server-only `MPESA_*` variables from .env.example with your eligible business account. Start in sandbox; use the correct paybill/till transaction type and shortcode/passkey. Set SITE_URL to a public HTTPS origin so `/api/mpesa-callback` is reachable.

Only a confirmed deposit quoted in whole KES can use M-Pesa; other currencies are never converted automatically. The API normalizes Kenyan phone numbers, uses the server quote, and selects one payment provider atomically to prevent card and M-Pesa checkout being initiated for the same deposit. The PIN is entered only on the customer’s phone. Callback data is not payment proof: the server queries Daraja and matches both stored request IDs before marking a deposit paid. Clients can check payment status; staff have review controls in the booking dialog. The daily scheduled task also checks up to ten pending M-Pesa requests.

Staff can release a provider-verified failed or rejected M-Pesa attempt for a new payment. Ambiguous requests remain locked for manual reconciliation in Daraja rather than risking a duplicate charge. If a provider accepted a request but the server could not persist its identifiers, staff must reconcile it directly before changing anything. Refunds remain in the provider dashboard. Validate live enrollment, callback delivery, query response fields, cancellation, timeouts, provider selection races and receipts before accepting money. No Daraja credentials, merchant account or live provider flow has been connected or verified here.

## Email and deposits

Set `RESEND_API_KEY` and `EMAIL_FROM` using your verified sender. Set `CRON_SECRET` to a strong random secret. The Vercel scheduler in vercel.json runs daily at 09:00 East Africa Time and queues reminders for the following day's confirmed bookings, then processes the email queue. Staff can also process or retry messages in Notifications. Provider configuration and scheduler availability must be verified on the chosen hosting plan before launch.

Set `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET`. Register `/api/stripe-webhook` for `checkout.session.completed` and `checkout.session.async_payment_succeeded`. Use Stripe test mode first. Staff confirm the booking and quote a deposit before checkout is available. Quotes cannot be changed while a checkout session exists or after payment. Card information is handled by Stripe, not stored by this website. Verify provider eligibility, supported currencies, cancellation/refund terms and webhook delivery for your business before enabling real payments.

Emails, invitations, storage and payments are implemented but no live accounts are connected. Local demos do not deliver messages or collect money.

## Deploy

Import this folder into a Vercel project. Select Vite, build `npm run build`, output `dist`; configure the environment variables in `.env.example`. Rewrites support `/admin` and `/portal`, with indexing restrictions and security headers. No hosted deployment was created. Cloudflare/domain setup can follow later.

## Before launch

Replace all reference photography, concept projects, illustrative prices, placeholder staff and contact/social details with real studio material. Add your approved booking, cancellation and privacy terms. Preferred booking dates are enquiries, not automatic reservations; staff must check availability. Session times use Africa/Nairobi (UTC+3).

Verify connected flows with an admin and two separate client accounts: enquiries, confirmations, invitations/password recovery, isolated project access, private uploads/downloads, feedback, test deposits/webhooks, receipts and scheduled reminders. The automated checks include an embedded PostgreSQL test of all four database scripts, interval exclusions, client ownership, storage policies, testimonial publishing and M-Pesa retry locks. These use a local Supabase-shaped Auth/Storage fixture and do not verify live Supabase or provider behavior. The local build and automated checks do not replace this account-connected acceptance test.

## Reference photography

Unsplash reference images illustrate the design and do not depict this studio or its clients: [studio](https://images.unsplash.com/photo-1598488035139-bdbb2231ce04), [microphone](https://images.unsplash.com/photo-1516280440614-37939bbacd81), [film](https://images.unsplash.com/photo-1492691527719-9d1e07e534b4), [live](https://images.unsplash.com/photo-1516450360452-9312f5e86fc7).

## Staff roles, documents and project messages

Owners have every control, including studio identity and Staff access. Managers handle bookings, calendar, availability, deposits, public content, client invitations and all projects. Producers see only assigned projects and can manage briefs, progress, updates, files, revisions and proposals. Engineers see only assigned projects and can deliver files, reply to clients and resolve revisions; they cannot edit progress or proposals, or see booking/payment records. The owner invites staff and assigns projects under Staff access. Public team profiles are separate from private staff accounts. Removing a staff membership or assignment takes effect on subsequent server requests and database reads. The demo role selector previews these controls without granting actual access.

Client projects includes branded session summaries and versioned proposals. Producers, managers and owners save proposal drafts for review and publish them to the client. Clients see only published versions; subsequent changes use a new version. An estimate is separate from the booking deposit. Downloads are standalone HTML documents with a Print / Save as PDF button, with responsive previews and A4 print styles. Summaries exclude staff notes, private storage paths and payment provider identifiers.

New deliverables, resolved revisions and published proposals queue client emails through the existing Resend outbox. Messages link to the authenticated portal, never to a public file. Clients control these project emails in Activity; turning them off cancels queued project messages. Session messages and receipts remain separate. The server checks the preference again before delivery. Local demos never send messages. Notifications shows queue failures for staff to retry; a file/project action still completes if its email cannot be queued.

## Language and launch previews

Visitors can switch English / Kiswahili using EN / SW in the header. Interface guidance, booking forms and availability labels change; booking values stay stable and the choice is saved on the device. Custom studio content remains in its authored language; private workspaces and printable documents currently use English. Extend src/locale.js for more visitor languages.

Settings controls the studio name, logo URL, homepage photo and description, reference-photo label, search title and search description. Add real staff profiles through Studio experience and actual releases through Projects. No real identities or releases have been invented.

The production build loads public studio settings when connected and generates search metadata, social previews and structured organization data. Once SITE_URL contains the real HTTPS origin, it also adds canonical links and a homepage sitemap. Rebuild after changing these public search details. The default social artwork is a generic sound/vision/feeling graphic with no claims about actual projects or clients. Admin and portal routes remain excluded from indexing. Private code is loaded only when its route is visited, audio waits until playback and images load progressively. The site includes a skip link, visible focus styles and reduced-motion support.

## Verify setup

Run `npm run check:setup` after setting environment values. This read-only check reports missing connections, a mismatched database URL, public secret prefixes, inaccessible database tables and missing owner membership. It never prints credential values, sends emails, charges payments or changes records. A successful result confirms configuration and database reachability; live sign-in, access isolation, private files, email delivery and payment callbacks still require acceptance testing.

Manager calendar mutations go through the workflow API; managers cannot directly insert, modify or delete reservations using the database API. New setup uses the updated launch.sql. For an already configured studio database, remove the three old manager write policies listed in database/reservation-permissions-patch.sql.

## Public media library and project galleries

Apply `database/media.sql` after `database/launch.sql` for existing or new installations. Owners, managers and producers can upload approved photos, audio and videos in **Media library**, reuse them in **Studio experience > Reel & audio**, and publish projects with a cover, audio/video link and up to 30 captioned gallery photos. Gallery photos can be reordered or removed from the project without deleting the library asset. Inline uploads and library selectors are also available in the project editor.

The separate `studio-public-media` bucket is public, accepts the listed image/audio/video formats and caps files at 50 MB. Public upload forms explain that files are public; the library requires confirmation of publishing permission. For larger videos use externally hosted video links. Prefer MP4 for video compatibility. Private deliveries stay in `studio-deliverables`. Registered public assets cannot be removed or overwritten through the browser storage API, so saved portfolio links remain stable. The library shows the newest 500 assets.

Producers can publish public portfolio content and edit showreel/audio fields, with server checks and database policies. They cannot edit packages, services, studio identity, staff, bookings or payments. Engineers keep their existing assigned-client-project access. New audio fields merge atomically into the existing experience so package/team/tour details survive.

`tests/media*.test.js` and the database suite verify media validation, gallery rules, role restrictions and storage policies. `scripts/media-acceptance.mjs [site-origin]` uses disposable accounts to test real image/audio uploads, public retrieval, portfolio galleries, draft isolation and denied client/engineer operations, then cleans up only its fixtures. It requires the existing local server/public environment values and prints no credentials.

## Website editor

Open `/admin` and select **Website editor** for a central, no-code content desk. Owners can edit the welcome headline, introduction, hero photo, phone/WhatsApp, email, location, social links and booking availability. The simplified hero preview updates while typing or choosing media; **Publish website changes** saves through the existing studio settings permissions. **Discard edits** restores the last saved values. Demo saves remain in the current browser session.

Cards lead to project galleries, the public media library, services/new offers, packages, reel, team, tour and testimonials. Managers can use the content desk shortcuts; contact and hero settings remain owner-only. New offers use the existing services and packages editors; this does not introduce a separate retail catalog or checkout. Public layout and database schema are unchanged.
