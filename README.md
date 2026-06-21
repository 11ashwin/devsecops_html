Here is a high-level snapshot of your project's architecture and milestones so far:

---

### Current Architecture Diagram

---

### Quick Project Summary

* **Code Baseline:** You have a clean, styled HTML/CSS portfolio portfolio tracking your cybersecurity profile.
* **Container Hardening:** Instead of a default setup, you built a custom `Dockerfile` that shifts security left. It strips away root execution privileges and runs Nginx under a strictly isolated user profile (`appuser`).
* **Artifact Lifecycle:** You took that container from a local build on your Mac (`:local`), verified its runtime boundaries, and successfully published it to a central cloud registry (**Docker Hub** at `11ashwin/devsecops_html:v1.0`).

Your project is now fully prepped to transition from local engineering to cloud deployment or automated pipeline orchestration!
