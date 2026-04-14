# Adapter Schema — 2026-04-14

This document defines the minimum schema for the first three supervised-test scenarios.

The schema is intentionally small.
Its purpose is to keep `execute-apply` and OpenClaw bundle generation aligned.

## Shared Fields

Every scenario should resolve these fields before real execution:

- `queue_id`
- `scenario_id`
- `task_types`
- `authority`
- `gate`
- `preferred_tools`
- `required_fields`
- `missing_fields`
- `blocked_reason`
- `success_note`
- `partial_note`

## Scenario: crm_followup

- `scenario_id`: `crm_followup`
- `task_types`:
  - `create_crm_record`
  - `read_base`
  - `send_crm_followup`
  - `send_message`
- `preferred_tools`:
  - `feishu_bitable_app_table_record`
  - `feishu_search_doc_wiki`
  - `feishu_im_user_message`
- `required_fields`:
  - `customer_key`
  - `followup_message`
- `blocked_if_missing`:
  - `customer_key`
- `partial_if_missing`:
  - `followup_message`
- `success_note_template`:
  - `CRM record updated and follow-up message sent`
- `partial_note_template`:
  - `CRM context prepared but manual follow-up still required`

## Scenario: expense_approval

- `scenario_id`: `expense_approval`
- `task_types`:
  - `create_expense`
  - `submit_approval`
- `preferred_tools`:
  - `feishu_bitable_app_table_record`
  - `feishu_drive_file`
- `required_fields`:
  - `amount`
  - `expense_type`
  - `expense_date`
  - `purpose`
- `blocked_if_missing`:
  - `amount`
  - `expense_type`
  - `expense_date`
  - `purpose`
- `partial_if_missing`:
  - `receipt_file_token`
- `success_note_template`:
  - `Expense payload prepared and routed to approval`
- `partial_note_template`:
  - `Expense prepared but supporting material still requires manual follow-up`

## Scenario: document_update

- `scenario_id`: `document_update`
- `task_types`:
  - `update_document`
  - `write_wiki`
- `preferred_tools`:
  - `feishu_fetch_doc`
  - `feishu_update_doc`
  - `feishu_search_doc_wiki`
- `required_fields`:
  - `document_ref`
  - `edit_instruction`
- `blocked_if_missing`:
  - `document_ref`
- `partial_if_missing`:
  - `edit_instruction`
- `success_note_template`:
  - `Document content updated successfully`
- `partial_note_template`:
  - `Target document resolved but content update still needs manual refinement`

## Scenario: ppal_marketing_ops

- `scenario_id`: `ppal_marketing_ops`
- `task_types`:
  - `read_base`
  - `read_document`
  - `create_document`
  - `update_document`
  - `send_message`
- `preferred_tools`:
  - `feishu_bitable_app_table_record`
  - `feishu_search_doc_wiki`
  - `feishu_create_doc`
  - `feishu_fetch_doc`
  - `feishu_update_doc`
  - `feishu_im_user_message`
- `default_context`:
  - `base_token=QRonbSCrBajWRtsZYrTjtUsep0d`
  - `user_table_id=tbl4sJd5HVE7u47v`
  - `cv_table_id=tbliH8JqoIWGgt9X`
  - `metrics_table_id=tblR58a8UANR4nC2`
  - `source_table_id=tbli5hWHQKH8AQxb`
  - `ssot_doc_url=https://www.larksuite.com/docx/BhN3d92LrohAokxqh2WjWEmRphh`
- `required_fields`:
  - `campaign_goal`
- `blocked_if_missing`:
  - `campaign_goal`
- `partial_if_missing`:
  - `segment_hint`
  - `destination_target`
- `normalization`:
  - `SFA -> PPAL Base`
  - `MA -> PPAL Base`
  - `Notion -> Lark Docs/Wiki`
  - `Slack -> Lark IM`
- `success_note_template`:
  - `PPAL marketing context normalized into Base, Docs, and IM execution steps`
- `partial_note_template`:
  - `PPAL marketing context prepared but segment or destination still needs manual confirmation`
