# Git History Cleanup Guide - credentials.txt Removal

**Project**: protonvpn-manager
**Task**: Remove credentials.txt from entire git history
**Date**: 2025-10-13
**Status**: READY FOR EXECUTION

⚠️ **WARNING**: This is a DESTRUCTIVE operation. Once executed, it CANNOT be undone. All collaborators will need to re-clone the repository.

---

## Prerequisites

**Completed**:
- ✅ Backup created: `/home/user/workspace/protonvpn-manager.backup.20251013_174741`
- ✅ Mirror repository prepared: `/tmp/protonvpn-mirror`
- ✅ filter-branch partially run (needs completion)

**Before proceeding, verify**:
- [ ] All team members have pushed their work
- [ ] No one is actively working on the repository
- [ ] You have communicated the history rewrite to all collaborators
- [ ] Backup is verified and accessible

---

## Method 1: Complete the Existing filter-branch (RECOMMENDED)

The filter-branch has already run but needs proper completion for a bare repository.

### Step 1: Complete the Rewrite

```bash
cd /tmp/protonvpn-mirror

# Update all refs to point to rewritten history
for ref in $(git for-each-ref --format='%(refname)' refs/original/); do
    new_ref=${ref#refs/original/}
    git update-ref -d "$ref"
    echo "Cleaned up $ref"
done

# Force update all remote branches to rewritten versions
git for-each-ref --format='%(refname)' refs/heads/ | while read ref; do
    echo "Processing $ref"
done
```

### Step 2: Aggressive Cleanup

```bash
cd /tmp/protonvpn-mirror

# Expire all reflog entries immediately
git reflog expire --expire=now --all

# Aggressive garbage collection
git gc --prune=now --aggressive

# Verify size reduction
du -sh .
```

### Step 3: Verify Removal

```bash
cd /tmp/protonvpn-mirror

# This should return NOTHING (or "fatal: Path 'credentials.txt' does not exist")
git log --all --full-history --source -- credentials.txt

# This should ERROR (file not found)
git show master:credentials.txt

# Check all branches
for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
    echo "Checking $branch..."
    git show $branch:credentials.txt 2>&1 | head -1
done
```

### Step 4: Force Push to Remote

⚠️ **POINT OF NO RETURN** ⚠️

```bash
cd /tmp/protonvpn-mirror

# Dry run first (safe - shows what would happen)
git push --force --all --dry-run
git push --force --tags --dry-run

# If dry run looks correct, execute for real
git push --force --all
git push --force --tags

echo "✅ History rewritten on remote"
```

### Step 5: Update Working Repository

```bash
# Move old repo to backup
cd /home/user/workspace
mv protonvpn-manager protonvpn-manager.old

# Fresh clone with clean history
git clone git@github.com:maxrantil/protonvpn-manager.git

# Verify credentials.txt is gone
cd protonvpn-manager
git log --all --full-history -- credentials.txt  # Should show nothing
ls -la credentials.txt  # Should not exist
```

---

## Method 2: Start Fresh with git-filter-repo (ALTERNATIVE)

If Method 1 has issues, use the modern git-filter-repo tool.

### Step 1: Install git-filter-repo

```bash
# On Artix/Arch Linux
sudo pacman -S git-filter-repo

# Or via pip
pip install --user git-filter-repo
```

### Step 2: Create Fresh Mirror

```bash
cd /tmp
rm -rf protonvpn-mirror-new
git clone --mirror git@github.com:maxrantil/protonvpn-manager.git protonvpn-mirror-new
cd protonvpn-mirror-new
```

### Step 3: Run git-filter-repo

```bash
cd /tmp/protonvpn-mirror-new

# Remove credentials.txt from all history
git filter-repo --invert-paths --path credentials.txt --force

# Verify removal
git log --all --full-history -- credentials.txt  # Should show nothing
```

### Step 4: Force Push

```bash
cd /tmp/protonvpn-mirror-new

# Restore remote configuration (filter-repo removes it)
git remote add origin git@github.com:maxrantil/protonvpn-manager.git

# Force push
git push --force --all
git push --force --tags
```

---

## Method 3: BFG Repo-Cleaner (EASIEST if Java available)

### Step 1: Install Java

```bash
# On Artix/Arch Linux
sudo pacman -S jre-openjdk
```

### Step 2: Run BFG

```bash
cd /tmp

# BFG is already downloaded at /tmp/bfg.jar
java -jar bfg.jar --delete-files credentials.txt protonvpn-mirror

cd protonvpn-mirror
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push
git push --force --all
git push --force --tags
```

---

## Post-Cleanup Actions

### 1. Notify All Collaborators

Send this message to anyone with repository access:

```
Subject: protonvpn-manager - Git History Rewrite Complete

The protonvpn-manager repository history has been rewritten to remove
credentials.txt. You must re-clone the repository.

Steps:
1. Commit and push any pending work to a remote branch
2. Delete your local repository: rm -rf protonvpn-manager
3. Clone fresh: git clone git@github.com:maxrantil/protonvpn-manager.git
4. Cherry-pick any local commits if needed

Do NOT attempt to pull or rebase your existing repository.

Timeline: Complete by [DATE]
```

### 2. Update Session Handoff

```bash
cd /home/user/workspace/protonvpn-manager

# Update SESSION_HANDOVER.md to note history cleanup
echo "
## Git History Cleanup - $(date +%Y-%m-%d)

✅ Removed credentials.txt from entire git history
- Method used: [filter-branch/filter-repo/BFG]
- Commits rewritten: 206
- Force pushed to remote: $(date)
- All collaborators notified
" >> SESSION_HANDOVER.md
```

### 3. Verify .gitignore

```bash
cd /home/user/workspace/protonvpn-manager

# Ensure credentials.txt remains ignored
grep -q "credentials.txt" .gitignore || echo "credentials.txt" >> .gitignore
```

### 4. Update Public Release Plan

```bash
# Mark as complete in PUBLIC_RELEASE_PLAN.md
sed -i 's/⏳ PENDING/✅ COMPLETE/' docs/PUBLIC_RELEASE_PLAN.md
```

---

## Troubleshooting

### Issue: "fatal: ref 'refs/heads/master' is at ... but expected ..."

**Solution**: Update refs manually
```bash
cd /tmp/protonvpn-mirror
git update-ref refs/heads/master $(git rev-parse refs/heads/master)
```

### Issue: "remote: error: denying non-fast-forward refs/heads/master"

**Solution**: GitHub branch protection enabled
1. Go to GitHub Settings → Branches
2. Temporarily disable branch protection on master
3. Force push
4. Re-enable branch protection

### Issue: "Everything up-to-date" (but file still in history)

**Solution**: Refs not updated properly
```bash
cd /tmp/protonvpn-mirror
git update-ref -d refs/original/refs/heads/master
git push --force --all
```

### Issue: File still appears in some commits

**Solution**: Check if refs/original/* exists
```bash
cd /tmp/protonvpn-mirror
git for-each-ref refs/original/
# If any output, delete them:
git for-each-ref --format='%(refname)' refs/original/ | xargs -r git update-ref -d
```

---

## Verification Checklist

After force push, verify on GitHub:

```bash
# 1. Clone fresh copy
cd /tmp
git clone git@github.com:maxrantil/protonvpn-manager.git verify-clean
cd verify-clean

# 2. Check history (should return NOTHING)
git log --all --full-history -- credentials.txt

# 3. Check master branch (should ERROR)
git show master:credentials.txt

# 4. Check all branches
for branch in $(git branch -r | grep -v HEAD); do
    echo "Checking $branch..."
    git show $branch:credentials.txt 2>&1 | grep -q "does not exist" && echo "✅ Clean" || echo "❌ STILL EXISTS"
done

# 5. Search all commits for credential patterns
git log --all -S "BBNTM4DDjnNPEyXU" --oneline
# Should return NOTHING

# 6. Verify repository size reduction
du -sh .git
# Should be smaller than before (old: ~XXX MB, new: ~YYY MB)
```

If ALL checks pass: ✅ **History cleanup successful!**

---

## Recovery (If Something Goes Wrong)

### Before Force Push:
- Original repository still intact at `/home/user/workspace/protonvpn-manager`
- Backup at `/home/user/workspace/protonvpn-manager.backup.20251013_174741`
- Nothing to recover - just delete `/tmp/protonvpn-mirror` and start over

### After Force Push (Urgent):
If you immediately realize there's a problem:

```bash
# GitHub keeps old refs for ~30 days in their backup
# Contact GitHub support IMMEDIATELY for ref recovery

# Or restore from backup and force push again
cd /home/user/workspace/protonvpn-manager.backup.20251013_174741
git remote add origin git@github.com:maxrantil/protonvpn-manager.git
git push --force --all
git push --force --tags
```

---

## Timeline

**Estimated Time**: 15-30 minutes total
- Preparation & verification: 5 minutes
- Execution (filter-branch/BFG): 2-5 minutes
- Force push: 1-2 minutes
- Verification: 5-10 minutes
- Collaborator notification: 5 minutes

**Optimal Execution Time**: During low-activity period (evening/weekend)

---

## Success Criteria

History cleanup is complete when:
- [ ] `git log --all --full-history -- credentials.txt` returns nothing
- [ ] `git show master:credentials.txt` returns "does not exist" error
- [ ] Fresh clone does not contain credentials.txt file
- [ ] No commits in any branch contain credential patterns
- [ ] All collaborators notified and have re-cloned
- [ ] Session handoff document updated
- [ ] Public release plan marked complete

---

**Created**: 2025-10-13
**Last Updated**: 2025-10-13
**Status**: READY FOR DOCTOR HUBERT TO EXECUTE
**Estimated Risk**: Medium (destructive but reversible from backup)
**Estimated Impact**: All git history rewritten, all collaborators must re-clone

---

**Doctor Hubert**: Execute this when ready. I recommend Method 1 (complete existing filter-branch) as it's already partially done. Take your time, by the book.
