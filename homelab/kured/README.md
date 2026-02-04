# Kured - Kubernetes Reboot Daemon

Automatically reboots nodes when `/var/run/reboot-required` exists (created by Ubuntu after updates).

## How It Works

```
apt upgrade installs kernel → /var/run/reboot-required created
        ↓
Kured detects sentinel file (checks hourly)
        ↓
Waits for reboot window (02:00-06:00)
        ↓
Acquires cluster lock (only 1 node at a time)
        ↓
Cordons node (no new pods scheduled)
        ↓
Drains pods (moves workloads to other nodes)
        ↓
Reboots
        ↓
Node comes back → Uncordons → Releases lock
        ↓
Next node can reboot if needed
```

## Node Setup: Unattended Upgrades

Run this on **each Ubuntu node** (SSH in):

```bash
# Install unattended-upgrades
sudo apt update
sudo apt install -y unattended-upgrades apt-listchanges

# Enable automatic updates
sudo dpkg-reconfigure -plow unattended-upgrades
# Select "Yes"
```

### Configure Updates

Edit `/etc/apt/apt.conf.d/50unattended-upgrades`:

```bash
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Recommended settings:

```
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

// Automatically remove unused dependencies
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";

// Don't reboot automatically - let Kured handle it
Unattended-Upgrade::Automatic-Reboot "false";

// Email notifications (optional)
// Unattended-Upgrade::Mail "your@email.com";
// Unattended-Upgrade::MailReport "only-on-error";

// Log to syslog
Unattended-Upgrade::SyslogEnable "true";
```

Enable the timer:

```bash
# Enable automatic update checks
sudo systemctl enable --now apt-daily.timer
sudo systemctl enable --now apt-daily-upgrade.timer

# Verify timers are active
sudo systemctl list-timers | grep apt
```

### Quick Setup Script

Or run this one-liner on each node:

```bash
sudo apt update && \
sudo apt install -y unattended-upgrades && \
sudo tee /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF
sudo sed -i 's/Unattended-Upgrade::Automatic-Reboot "true"/Unattended-Upgrade::Automatic-Reboot "false"/' /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null || true
```

## Livepatch (Optional)

Ubuntu Livepatch applies kernel security patches without rebooting. Free for up to 5 machines.

### Pros
- Critical kernel CVEs patched immediately
- No reboot needed for most security fixes
- Peace of mind for public-facing nodes

### Cons  
- Only kernel patches (not userspace)
- Eventually still needs reboot for major updates
- Requires Ubuntu Pro (free tier available)

### Setup (if you want it)

```bash
# Get a free token at https://ubuntu.com/pro
sudo pro attach <your-token>

# Enable livepatch
sudo pro enable livepatch

# Check status
sudo pro status
canonical-livepatch status
```

### My Recommendation

For a homelab with Kured already handling reboots: **Livepatch is nice but not essential.**

- Your nodes reboot automatically at night anyway
- 3-node HA means one node rebooting doesn't cause downtime
- Livepatch is more valuable for servers that *can't* reboot

If your Hetzner VPS is public-facing, Livepatch there might be worth it for faster kernel CVE response.

## Monitoring Kured

```bash
# Check Kured pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=kured

# View logs
kubectl logs -n kube-system -l app.kubernetes.io/name=kured

# Check if any node is holding the reboot lock
kubectl get ds -n kube-system kured -o jsonpath='{.metadata.annotations}'
```

## Testing

```bash
# Simulate a pending reboot on a node (SSH to node)
sudo touch /var/run/reboot-required

# Watch Kured detect it
kubectl logs -n kube-system -l app.kubernetes.io/name=kured -f

# It will wait for the configured time window (02:00-06:00)
# To test immediately, temporarily change startTime/endTime in the Helm values
```

## Notifications (Optional)

Add Slack notifications by uncommenting in `application.yaml`:

```yaml
notifyUrl: "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
messageTemplateDrain: "🔄 Draining node %s for reboot"
messageTemplateReboot: "🔃 Rebooting node %s"  
messageTemplateUncordon: "✅ Node %s back online"
```
