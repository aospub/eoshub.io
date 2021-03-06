// Must import babel-polyfill only one time to support ES7!
import 'babel-polyfill';
import '../stylesheets/style.scss';

import ScatterJS from 'scatterjs-core';
import ScatterEOS from 'scatterjs-plugin-eosjs';
import eos from 'eosjs';
import ecc from 'eosjs-ecc';
import _ from 'lodash';

import loadTV from './TradingView/loader';

import Elm from '../elm/Main'; // eslint-disable-line import/no-unresolved
import {
  getWalletStatus,
  authenticateAccount,
  invalidateAccount,
  getAuthInfo,
} from './wallet';
import { announceLocalStorageKey } from './constant';
import { scatterConfig, eosjsConfig } from './config';
import {
  getScatter,
  updateScatter,
} from './state';

function createResponseStatus() {
  const { account, authority } = getScatter();
  return {
    status: getWalletStatus(),
    account,
    authority,
  };
}

function createPushActionReponse(code, action, type, msg) {
  return {
    code,
    action,
    type_: !type ? '' : type,
    message: !msg ? '' : msg,
  };
}

const target = document.getElementById('elm-target');

const app = Elm.Main.embed(target, {
  rails_env: process.env.RAILS_ENV,
});

app.ports.checkWalletStatus.subscribe(async () => {
  // the delay is required to wait for loading scatter or changing component subscription
  window.setTimeout(
    () => {
      app.ports.receiveWalletStatus.send(createResponseStatus());
    },
    500,
  );
});

// TODO(heejae): After wallet auth success/error message popup is devised,
// deal with cases.
app.ports.authenticateAccount.subscribe(async () => {
  try {
    await authenticateAccount();
  } catch (err) {
    if (err.isError && err.isError === true) {
      // Deal with scatter error.
      console.error(err);
    }
  }
  app.ports.receiveWalletStatus.send(createResponseStatus());
});

app.ports.invalidateAccount.subscribe(async () => {
  try {
    await invalidateAccount();
  } catch (err) {
    if (err.isError && err.isError === true) {
      // Deal with scatter error.
      console.error(err);
    }
  }
  app.ports.receiveWalletStatus.send(createResponseStatus());
});

app.ports.pushAction.subscribe(async ({ actionName, actions }) => {
  try {
    const scatter = getScatter();
    const options = { authorization: [`${scatter.account}@${scatter.authority}`] };
    const contractNames = _.map(actions, ({ account }) => account);
    await scatter.eosjsClient.transaction(contractNames, (contracts) => {
      _.forEach(actions, ({ action, payload, account }) => {
        const dotReplacedAccount = _.replace(account, '.', '_');
        contracts[dotReplacedAccount][action](payload, options);
      });
    });
    app.ports.receivePushActionResponse.send(createPushActionReponse(200, actionName));
  } catch (err) {
    if (err.isError && err.isError === true) {
      // Deal with scatter error.
      const { code, type, message } = err;
      if (type === 'signature_rejected') { return; }

      app.ports.receivePushActionResponse.send(
        createPushActionReponse(code, actionName, type, message),
      );
      return;
    }

    try {
      // Handle blockchain errors.
      const errObject = JSON.parse(err);
      if (errObject.code === 500 && errObject.error) {
        const { name, code, what } = errObject.error;
        app.ports.receivePushActionResponse.send(
          createPushActionReponse(code, actionName, name, what),
        );
      }
    } catch (e) {
      console.error(e);
    }
  }
});

app.ports.generateKeys.subscribe(async () => {
  ecc.PrivateKey.randomKey().then((privateKey) => {
    // Create a new random private key
    const privateWif = privateKey.toWif();

    // Convert to a public key
    const pubkey = ecc.PrivateKey.fromString(privateWif).toPublic().toString();

    const keys = { privateKey: privateWif, publicKey: pubkey };
    app.ports.receiveKeys.send(keys);
  });
});

app.ports.copy.subscribe(async () => {
  document.querySelector('#key').select();
  document.execCommand('copy');
});

app.ports.loadChart.subscribe(async () => {
  requestAnimationFrame(async () => {
    await loadTV();
  });
});

app.ports.openWindow.subscribe(async ({ url, width, height }) => {
  const specs = `top=${(window.screen.height - height) * 0.5},left=${(window.screen.width - width) * 0.5},width=${width},height=${height}`;
  window.open(url, '_blank', specs);
});

app.ports.checkLocale.subscribe(() => {
  app.ports.receiveLocale.send(navigator.language || navigator.userLanguage);
});

app.ports.checkValueFromLocalStorage.subscribe(() => {
  let parsedValue = null;
  try {
    const value = window.localStorage.getItem(announceLocalStorageKey);
    if (value) {
      parsedValue = JSON.parse(value);
    }
  } catch (err) {
    console.error(err);
  }
  app.ports.receiveValueFromLocalStorage.send(parsedValue);
});

app.ports.setValueToLocalStorage.subscribe((value) => {
  window.localStorage.setItem(announceLocalStorageKey, JSON.stringify(value));
});

function initScatter() {
  // const ScatterJS = await System.import('scatterjs-core'); // eslint-disable-line no-undef
  ScatterJS.plugins(new ScatterEOS());
  ScatterJS.scatter.connect('eoshub.io').then((connected) => {
    if (!connected) {
      console.error('Failed to connect with Scatter.');
      return;
    }

    const { scatter } = ScatterJS;

    const eosjs = scatter.eos(scatterConfig, eos, eosjsConfig, 'https');
    let scatterState = {
      scatterClient: scatter,
      eosjsClient: eosjs,
      account: '',
      authority: '',
    };

    if (scatter.identity) {
      const { authority, name } = getAuthInfo(scatter.identity);
      scatterState = {
        ...scatterState,
        account: name,
        authority,
      };
    }

    updateScatter(scatterState);
    app.ports.receiveWalletStatus.send(createResponseStatus());
    window.ScatterJS = null;
  });
}

initScatter();
