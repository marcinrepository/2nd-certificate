*** Settings ***
Documentation       Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.

Library             RPA.HTTP
Library             RPA.FileSystem
Library             RPA.Excel.Files
Library             RPA.Browser.Selenium    auto_close=True
Library             RPA.Tables
Library             RPA.Robocorp.Vault
Library             RPA.PDF
Library             RPA.Archive
Library             RPA.Dialogs


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Clean old data
    Download Excel File
    Open the robot order website
    Submit orders
    [Teardown]    Close Window


*** Keywords ***
Clean old data
    Create Directory    ${output_dir}${/}receipts
    Create Directory    ${output_dir}${/}screenshots
    Empty directory    ${output_dir}${/}receipts
    Empty directory    ${output_dir}${/}screenshots
    Remove File    ${output_dir}${/}zip_file.zip    missing_ok=True
    Remove File    ${output_dir}${/}orders.csv    missing_ok=True

Download Excel File
    ${link_to_excel_file}=    Ask about link to excel file - run dialog
    #Download    http://robotsparebinindustries.com/orders.csv    overwrite=True    verify=False
    Download    ${link_to_excel_file}    verify=False
    Copy File    orders.csv    ${OUTPUT_DIR}${/}orders.csv

Ask about link to excel file - run dialog
    Add heading    Please provide link to download orders.csv
    Add text input    address    label=website address to download file
    ${dialog_data}=    Run dialog    title=Please provide details    on_top=${True}    height=600
    RETURN    ${dialog_data}[address]

Open the robot order website
    Open Available Browser    https://robotsparebinindustries.com/#/
    Wait Until Page Contains Element    id:username    timeout=20
    Go To    https://robotsparebinindustries.com/#/robot-order

Submit orders
    ${orders_table}=    Read table from CSV    orders.csv    header=True
    ${screenshots_dir}=    Set Variable    ${Output_DIR}${/}screenshots
    ${receipts_dir}=    Set Variable    ${Output_DIR}${/}receipts

    FOR    ${order_row}    IN    @{orders_table}
        Click annoying button containg - I guess so
        Fill the form    ${order_row}
        Wait until the whole robot image will be loaded and take a screenshot    ${screenshots_dir}    ${order_row}
        Try to click submit button 10 times
        Save receipt to pdf    ${receipts_dir}    ${order_row}
        Add screenshot to receipt PDF    ${screenshots_dir}    ${receipts_dir}    ${order_row}
        Click Element If Visible    id:order-another
    END

    Create zip file with all receipts merged with screenshots

Click annoying button containg - I guess so
    Click Button When Visible    xpath://button[@class="btn btn-danger"]

Fill the form
    [Arguments]    ${order_row}

    ${head_order_number}=    Set Variable    ${order_row}[Head]
    Select From List By Value    id:head    ${head_order_number}

    ${body_part_number}=    Set Variable    ${order_row}[Body]
    Click Button    xpath://input[@id='id-body-${body_part_number}']

    ${legs_part_number}=    Set Variable    ${order_row}[Legs]
    Input Text    xpath://input[@placeholder="Enter the part number for the legs"]    ${legs_part_number}

    ${address}=    Set Variable    ${order_row}[Address]
    Input Text    xpath://input[@id="address"]    ${address}

    Click Button    id:preview

Wait until the whole robot image will be loaded and take a screenshot
    [Arguments]    ${screenshots_dir}    ${order_row}
    #Test of vault usage - no credentials
    ${secret}=    Get Secret    VaultTest
    #Log To Console    ${secret}

    #Wait Until Element Is Visible    xpath://img[@alt="Head"]
    #Wait Until Element Is Visible    xpath://img[@alt="Body"]
    #Wait Until Element Is Visible    xpath://img[@alt="Legs"]
    Wait Until Element Is Visible    xpath:${secret}[head_xpath]
    Wait Until Element Is Visible    xpath:${secret}[body_xpath]
    Wait Until Element Is Visible    xpath:${secret}[legs_xpath]

    #Save screenshot of robot model preview:
    RPA.Browser.Selenium.Screenshot
    ...    id:robot-preview-image
    ...    ${screenshots_dir}${/}screenshot${order_row}[Order number].png

Try to click submit button 10 times
    FOR    ${counter}    IN RANGE    0    11
        IF    ${counter} == ${10}
            Fail    I tried to press submit 10 times but receipt is still not visible
        END

        ${is_receipt_visible}=    RPA.Browser.Selenium.Is Element Visible    id:order-completion

        IF    ${is_receipt_visible} == ${True}
            BREAK
        ELSE
            Click Button    id:order
        END
    END

Save receipt to pdf
    [Arguments]    ${receipts_dir}    ${order_row}
    ${receipt_content}=    Get Element Attribute    id:order-completion    outerHTML
    Html To Pdf    ${receipt_content}    ${receipts_dir}${/}Receipt${order_row}[Order number].pdf

Add screenshot to receipt PDF
    [Arguments]    ${screenshots_dir}    ${receipts_dir}    ${order_row}
    #Add robot's model screenshot to receipt PDF
    Add Watermark Image To PDF
    ...    image_path=${screenshots_dir}${/}screenshot${order_row}[Order number].png
    ...    source_path=${receipts_dir}${/}Receipt${order_row}[Order number].pdf
    ...    output_path=${receipts_dir}${/}Receipt${order_row}[Order number].pdf

Create zip file with all receipts merged with screenshots
    Remove File    ${Output_DIR}${/}zip_file.zip    missing_ok=True
    Archive Folder With Zip    ${Output_DIR}${/}Receipts${/}    ${Output_DIR}${/}zip_file.zip
