#!/bin/bash

# Robust date validation function that works on both Linux and macOS
validate_date() {
    local date_str="$1"
    
    # Try GNU date format first (Linux)
    if date -d "$date_str" "+%Y-%m-%d" >/dev/null 2>&1; then
        return 0
    fi
    
    # Try BSD date format (macOS)
    if date -j -f "%Y-%m-%d" "$date_str" "+%Y-%m-%d" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

# Function to add days that works on both Linux and macOS
add_days() {
    local date_str="$1"
    local days="$2"
    
    # Try GNU date first (Linux)
    if date -d "$date_str + $days days" "+%Y-%m-%d" 2>/dev/null; then
        return
    fi
    
    # Fallback to BSD date (macOS)
    date -j -v +"${days}d" -f "%Y-%m-%d" "$date_str" "+%Y-%m-%d"
}

# Function to get day of week (1-7, where 1 is Monday)
get_day_of_week() {
    local date_str="$1"
    
    # Try GNU date first (Linux)
    if dow=$(date -d "$date_str" +%u 2>/dev/null); then
        echo "$dow"
        return
    fi
    
    # Fallback to BSD date (macOS)
    date -j -f "%Y-%m-%d" "$date_str" +%u
}

# Function to check if a date is a weekend (Saturday or Sunday)
is_weekend() {
    local date_str="$1"
    local day_of_week=$(get_day_of_week "$date_str")
    [[ $day_of_week -ge 6 ]] && return 0 || return 1
}

# Initialize the beautiful-timeline.txt file
echo "Git Commit Timeline" > beautiful-timeline.txt
echo "===================" >> beautiful-timeline.txt
echo "" >> beautiful-timeline.txt

# Prompt for start date
while true; do
    read -p "Enter start date (YYYY-MM-DD): " start_date
    if validate_date "$start_date"; then
        break
    else
        echo "Invalid date format. Please use YYYY-MM-DD."
    fi
done

# Prompt for end date
while true; do
    read -p "Enter end date (YYYY-MM-DD): " end_date
    if validate_date "$end_date"; then
        if [[ "$(date -d "$end_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$end_date" +%s)" -lt "$(date -d "$start_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$start_date" +%s)" ]]; then
            echo "End date must be after start date."
        else
            break
        fi
    else
        echo "Invalid date format. Please use YYYY-MM-DD."
    fi
done

# Ask about excluding weekends
read -p "Exclude weekends? (y/n): " exclude_weekends
exclude_weekends=${exclude_weekends,,} # convert to lowercase
[[ "$exclude_weekends" == "y" ]] && exclude_weekends=true || exclude_weekends=false

# Prompt for commits per day
while true; do
    read -p "Number of commits per day (1-10): " commits_per_day
    if [[ "$commits_per_day" =~ ^[1-9]$|^10$ ]]; then
        break
    else
        echo "Please enter a number between 1 and 10."
    fi
done

# Initialize Git repo if not already one
if [ ! -d .git ]; then
    git init
fi

# Generate commits for each day in the range
current_date="$start_date"
while true; do
    # Convert dates to seconds for comparison
    current_sec=$(date -d "$current_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$current_date" +%s)
    end_sec=$(date -d "$end_date" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$end_date" +%s)
    
    # Break loop when we pass the end date
    if [ "$current_sec" -gt "$end_sec" ]; then
        break
    fi
    
    # Skip weekends if requested
    if $exclude_weekends && is_weekend "$current_date"; then
        echo "Skipping weekend: $current_date"
        current_date=$(add_days "$current_date" 1)
        continue
    fi
    
    # Generate random times for commits
    for ((i=1; i<=commits_per_day; i++)); do
        # Generate random hour (9-17 for work hours)
        hour=$((9 + RANDOM % 9))
        minute=$((RANDOM % 60))
        second=$((RANDOM % 60))
        
        # Format the datetime for Git
        git_date="${current_date}T${hour}:${minute}:${second}"
        
        # Add to timeline file
        echo "Commit on $git_date" >> beautiful-timeline.txt
        
        # Stage the file
        git add beautiful-timeline.txt
        
        # Create the commit with specific date
        export GIT_AUTHOR_DATE="$git_date"
        export GIT_COMMITTER_DATE="$git_date"
        git commit -m "Commit on $git_date" --no-verify --quiet
    done
    
    # Move to next day
    current_date=$(add_days "$current_date" 1)
done

echo ""
echo "Done! Created commits between $start_date and $end_date."
echo "Timeline saved to beautiful-timeline.txt"