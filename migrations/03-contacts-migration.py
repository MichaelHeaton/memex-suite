"""Migration 03 — Contacts
Imports CRM/Person/*.md — parses frontmatter (email, phone, org, role).
Builds contact_relationships from "Reports To" fields.
Run: python migrations/03-contacts-migration.py --vault <path> --api <base_url>
"""
