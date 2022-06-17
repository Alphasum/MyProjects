#/usr/bin/env python3
from ast import Break
def check_login():
    while True:
        username = input('Enter your username:\n')
        pin = input('Enter your pin:\n')
        if username in atmusers["username"] and pin in atmusers["pin"]:
            True
            break
        else: 
            print ('Incorrect input, try again')
            False
def withdraw():
    while True:
            OldKSH=atmusers['balance']['KSH']
            withdrawaLKSH=int(input("Enter amount you wish to withdraw: \n"))
            if OldKSH >= withdrawaLKSH:
                newKSH = OldKSH - withdrawaLKSH
                print("Transaction successful! New balance is: ", newKSH)
                updatedbalance={"balance":{'KSH':newKSH,'USD':0}}
                atmusers.update(updatedbalance)
                True
                break
            else:
                print('Insufficient balance. Try another amount')
                False
def receipt():
    while True:
        receipts=input("Do you want a receipt: yes or no: \n")
        if receipts=='yes':
            print("KENAI BANK")
            print("Reciept for user ", atmusers["username"])
            print("Your balance is: ", atmusers["balance"])
            print("Thank You for being our Loyal customer. \n Serving The Nation")
            True
            break
        elif receipts=='no':
            print("Exiting")
            True
            break    
        else:
            print("Invalid input value. Enter yes or no: \n")
            False
def check():
    print('Your balance is ', atmusers["balance"])
def Menu():
    while True:
        status =int(input("Press 1 to withdraw cash, Press 2 to check balance \n"))
        if status == 1:
            withdraw()
            receipt()
            Quit()
            True
            break
        elif status == 2:
            check()
            receipt()  
            Quit()
            True
            break
        else:
            print("Invalid input. Enter 1 or 2")
            False
def Quit():
    go=input("Do you want to perform another transaction? yes or exit: \n")
    if go=='yes': 
        Menu()
    elif go=='exit':
        print("Ending session")
atmusers={"username":"trial","pin":"0000","balance":{'KSH':140, 'USD':0}}
print("Welcome to KENAI BANK: ")
print("Login for existing user")
check_login(); 
print('Welcome to ATM Menu')
Menu()


