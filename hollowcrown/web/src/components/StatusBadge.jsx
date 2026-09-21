import React from 'react';

const styles = {
  active:     'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800',
  'on-leave': 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800',
  terminated: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700',
};

const labels = {
  active:     'Active',
  'on-leave': 'On Leave',
  terminated: 'Terminated',
};

export default function StatusBadge({ status }) {
  return (
    <span className={styles[status] || styles.active}>
      {labels[status] || status}
    </span>
  );
}
