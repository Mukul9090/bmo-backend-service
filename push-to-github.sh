#!/bin/bash
# Script to push code to GitHub

echo "=== Pushing to GitHub ==="
echo ""

# Check if remote exists
if git remote get-url origin > /dev/null 2>&1; then
    echo "Remote 'origin' already exists:"
    git remote get-url origin
    echo ""
    read -p "Do you want to use this remote? (y/n): " use_existing
    if [ "$use_existing" != "y" ]; then
        echo "Please set your GitHub repository URL manually:"
        echo "  git remote set-url origin https://github.com/YOUR_USERNAME/BMO.git"
        exit 1
    fi
else
    echo "No remote configured. Please provide your GitHub repository URL:"
    echo "Example: https://github.com/Mukul9090/BMO.git"
    read -p "Enter repository URL: " repo_url
    
    if [ -z "$repo_url" ]; then
        echo "Error: Repository URL is required"
        exit 1
    fi
    
    git remote add origin "$repo_url"
    echo "Remote added: $repo_url"
fi

echo ""
echo "=== Pushing to GitHub ==="
git branch -M main
git push -u origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Successfully pushed to GitHub!"
    echo ""
    echo "Next steps:"
    echo "1. Go to your GitHub repository"
    echo "2. Settings → Secrets → Actions"
    echo "3. Add DOCKER_USERNAME and DOCKER_PASSWORD secrets"
else
    echo ""
    echo "❌ Push failed. Common issues:"
    echo "- Authentication required (use GitHub token or SSH)"
    echo "- Repository doesn't exist (create it on GitHub first)"
    echo "- Check your GitHub credentials"
fi

