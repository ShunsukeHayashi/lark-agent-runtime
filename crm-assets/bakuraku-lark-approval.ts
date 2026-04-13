import { getTenantToken } from './auth.js'

const LARK_API = 'https://open.larksuite.com/open-apis'

export interface ApproveTaskParams {
  instance_code: string
  task_id: string
  userToken: string
  comment?: string
}

/**
 * Approve an approval task using the approver's user_access_token.
 * Requires scope: approval:task:write
 */
export async function approveTask({
  instance_code,
  task_id,
  userToken,
  comment = '承認します',
}: ApproveTaskParams): Promise<void> {
  const res = await fetch(`${LARK_API}/approval/v4/tasks/approve`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${userToken}` },
    body: JSON.stringify({
      approval_code: process.env['EXPENSE_APPROVAL_CODE'],
      instance_code,
      task_id,
      comment,
    }),
  })
  const data = (await res.json()) as { code: number; msg?: string }
  if (data.code !== 0) {
    throw new Error(`approveTask failed (instance=${instance_code}): ${data.msg ?? JSON.stringify(data)}`)
  }
}

/**
 * Reject an approval task using the approver's user_access_token.
 * Requires scope: approval:task:write
 */
export async function rejectTask({
  instance_code,
  task_id,
  userToken,
  comment = '却下しました',
}: ApproveTaskParams): Promise<void> {
  const res = await fetch(`${LARK_API}/approval/v4/tasks/reject`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${userToken}` },
    body: JSON.stringify({
      approval_code: process.env['EXPENSE_APPROVAL_CODE'],
      instance_code,
      task_id,
      comment,
    }),
  })
  const data = (await res.json()) as { code: number; msg?: string }
  if (data.code !== 0) {
    throw new Error(`rejectTask failed (instance=${instance_code}): ${data.msg ?? JSON.stringify(data)}`)
  }
}

/**
 * Create an Approval instance for an expense application.
 * Replaces the n8n bakuraku-approval-create workflow.
 * Requires scope: approval:instance:write
 */
export async function createApprovalInstance(params: {
  applicantId: string   // open_id of the applicant
  formJson: string      // JSON string of form fields per Approval template
  nodeApproverIds?: string[] // open_ids of approvers for the first node
}): Promise<{ instanceCode: string }> {
  const token = await getTenantToken()
  const approvalCode = process.env['EXPENSE_APPROVAL_CODE']
  if (!approvalCode) throw new Error('EXPENSE_APPROVAL_CODE is not set')

  const body: Record<string, unknown> = {
    approval_code: approvalCode,
    user_id: params.applicantId,
    form: params.formJson,
  }
  if (params.nodeApproverIds?.length) {
    body['node_approver_open_id_list'] = [
      { open_ids: params.nodeApproverIds },
    ]
  }

  const res = await fetch(`${LARK_API}/approval/v4/instances`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  })
  const data = (await res.json()) as { code: number; msg?: string; data?: { instance_code?: string } }
  if (data.code !== 0) {
    throw new Error(`createApprovalInstance failed: ${data.msg ?? JSON.stringify(data)}`)
  }
  return { instanceCode: data.data?.instance_code ?? '' }
}
