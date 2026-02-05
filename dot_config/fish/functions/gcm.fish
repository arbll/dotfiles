function gcm --description "Checkout main branch (main/prod/master in order)"
    # Try branches in order: main, prod, master
    for branch in main prod master
        # Check if branch exists locally
        if git show-ref --verify --quiet refs/heads/$branch
            git checkout $branch
            return 0
        # Check if branch exists remotely
        else if git show-ref --verify --quiet refs/remotes/origin/$branch
            git checkout $branch
            return 0
        end
    end

    # If no main branch found, show error
    echo "Error: Could not find main branch (tried main, prod, master)" >&2
    return 1
end
