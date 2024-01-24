import random
import time

# Initialize an empty set to store selected numbers
selected_numbers = set()

while True:
    if len(selected_numbers) > 10:
        # Clear the set and add a new random number if there are more than 10 numbers
        selected_numbers.clear()
        selected_numbers.add(random.randint(1, 100))
    else:
        # Add a new random number until there are 10 unique numbers
        selected_numbers.add(random.randint(1, 100))

    # Exit the loop if 10 unique numbers have been generated
    if len(selected_numbers) == 10:
        break

# Sort and print the 10 unique numbers
print("Randomly selected 10 unique numbers: ", sorted(selected_numbers))

# Wait for 10 minutes (600 seconds)
time.sleep(600)